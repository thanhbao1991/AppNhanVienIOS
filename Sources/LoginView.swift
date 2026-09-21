import SwiftUI

struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @State private var taiKhoan = Prefs.lastTaiKhoan
    @State private var matKhau = ""
    @State private var showMatKhau = false
    @State private var loading = false
    @State private var errorText: String?
    @FocusState private var focusedField: Field?
    private enum Field { case taiKhoan, matKhau }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.brandPrimary, Color.brandPrimary.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // ScrollView (thay vì VStack trần) để SwiftUI tự tránh bàn phím - VStack đứng riêng
            // trong ZStack KHÔNG được hệ thống tự đẩy lên khi bàn phím hiện.
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 40)

                    logoHeader
                        .padding(.bottom, 32)

                    VStack(spacing: 22) {
                        if let errorText {
                            HStack(spacing: 8) {
                                Text("⚠️")
                                Text(errorText)
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        }

                        manualForm
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color(.secondarySystemGroupedBackground))
                            .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
                    )
                }
                .padding(28)
                .frame(maxWidth: 400)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var logoHeader: some View {
        VStack(spacing: 8) {
            Text("Đenn Coffee")
                .font(.system(size: 34, weight: .bold, design: .rounded))
            Text("Chi tiêu — dành cho nhân viên")
                .font(.subheadline.weight(.medium))
                .opacity(0.85)
        }
        .foregroundColor(.white)
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
    }

    private var manualForm: some View {
        VStack(spacing: 16) {
            fieldContainer(icon: "👤", isFocused: focusedField == .taiKhoan) {
                TextField("Tài khoản", text: $taiKhoan)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .taiKhoan)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .matKhau }
            }

            fieldContainer(icon: "🔒", isFocused: focusedField == .matKhau) {
                Group {
                    if showMatKhau {
                        TextField("Mật khẩu", text: $matKhau)
                    } else {
                        SecureField("Mật khẩu", text: $matKhau)
                    }
                }
                .focused($focusedField, equals: .matKhau)
                .submitLabel(.go)
                .onSubmit { Task { await doLogin() } }

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { showMatKhau.toggle() }
                } label: {
                    Text(showMatKhau ? "🙈" : "👁️")
                        .foregroundColor(.secondary)
                }
            }

            Button {
                Task { await doLogin() }
            } label: {
                ZStack {
                    if loading {
                        ProgressView().tint(.white)
                    } else {
                        Text("Đăng nhập")
                            .font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .foregroundColor(.white)
            .background(
                (taiKhoan.isEmpty || matKhau.isEmpty || loading) ? Color.brandPrimary.opacity(0.35) : Color.brandPrimary,
                in: RoundedRectangle(cornerRadius: 14)
            )
            .shadow(
                color: Color.brandPrimary.opacity((taiKhoan.isEmpty || matKhau.isEmpty || loading) ? 0 : 0.35),
                radius: 12, x: 0, y: 6
            )
            .disabled(loading || taiKhoan.isEmpty || matKhau.isEmpty)
            .animation(.easeInOut(duration: 0.15), value: taiKhoan.isEmpty || matKhau.isEmpty)
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func fieldContainer<Content: View>(icon: String, isFocused: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(icon).frame(width: 20)
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(isFocused ? Color.brandPrimary : Color(.separator).opacity(0.4), lineWidth: isFocused ? 1.5 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: isFocused)
    }

    private func doLogin() async {
        guard !taiKhoan.isEmpty, !matKhau.isEmpty else {
            errorText = "Nhập tài khoản và mật khẩu."
            return
        }
        loading = true
        errorText = nil
        let result = await APIClient.shared.login(taiKhoan: taiKhoan, matKhau: matKhau)
        loading = false
        switch result {
        case .success(let resp):
            guard let token = resp.token else {
                errorText = "Phản hồi từ server không hợp lệ."
                return
            }
            Prefs.lastTaiKhoan = taiKhoan
            Prefs.saveSession(token: token, refreshToken: resp.refreshToken, displayName: resp.tenHienThi)
            isLoggedIn = true
        case .rejected(let message):
            errorText = message
        case .networkError:
            errorText = "Không kết nối được server, thử lại sau."
        }
    }
}
