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
        // ScrollView để SwiftUI tự đẩy form lên khi bàn phím hiện.
        ScrollView {
            VStack(spacing: 28) {
                logoHeader
                    .padding(.top, 72)

                VStack(spacing: 14) {
                    if let errorText {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    manualForm
                }
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var logoHeader: some View {
        VStack(spacing: 14) {
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 84, height: 84)
                .background(
                    LinearGradient(colors: [Color.brandPrimary.opacity(0.85), Color.brandPrimary], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
                .shadow(color: Color.brandPrimary.opacity(0.3), radius: 12, x: 0, y: 6)
            VStack(spacing: 4) {
                Text("Đenn Coffee")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Ứng dụng nhân viên")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var manualForm: some View {
        VStack(spacing: 16) {
            fieldContainer(icon: "person", isFocused: focusedField == .taiKhoan) {
                TextField("Tài khoản", text: $taiKhoan)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .taiKhoan)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .matKhau }
            }

            fieldContainer(icon: "lock", isFocused: focusedField == .matKhau) {
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
                    Image(systemName: showMatKhau ? "eye.slash" : "eye")
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
                        Text("Đăng nhập").font(.headline)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 30)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .controlSize(.large)
            .disabled(loading || taiKhoan.isEmpty || matKhau.isEmpty)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private func fieldContainer<Content: View>(icon: String, isFocused: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(isFocused ? .brandPrimary : .secondary).frame(width: 20)
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 52)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isFocused ? Color.brandPrimary : Color.clear, lineWidth: 1.5)
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
