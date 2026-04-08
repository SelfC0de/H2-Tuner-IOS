import SwiftUI

struct ServersView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var vpnManager: VPNManager
    @Binding var toast: ToastMessage?

    @State private var showAddSheet = false
    @State private var editingServer: ServerConfig? = nil
    @State private var searchText = ""
    @FocusState private var searchFocused: Bool

    var filteredServers: [ServerConfig] {
        if searchText.isEmpty { return settings.savedServers }
        return settings.savedServers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.host.localizedCaseInsensitiveContains(searchText) ||
            $0.protocol.displayName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar
                .padding(.top, 60)

            searchBar
                .padding(.top, 16)
                .padding(.horizontal, 20)

            if settings.savedServers.isEmpty {
                emptyState
            } else {
                serverList
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddServerSheet(toast: $toast)
        }
        .sheet(item: $editingServer) { server in
            EditServerSheet(server: server, toast: $toast)
        }
    }

    private var headerBar: some View {
        HStack {
            Text("Серверы")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Spacer()
            Button {
                showAddSheet = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(Color(hex: "#7C5CFC"))
                    .shadow(color: Color(hex: "#7C5CFC").opacity(0.6), radius: 6)
            }
        }
        .padding(.horizontal, 20)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(Color(hex: "#8A9BB8"))
                TextField("Поиск серверов", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .focused($searchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Готово") { searchFocused = false }
                                .foregroundColor(Color(hex: "#5CF0FC"))
                                .fontWeight(.semibold)
                        }
                    }
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color(hex: "#666680"))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(hex: "#1A1A2E"))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(searchFocused ? Color(hex: "#7C5CFC").opacity(0.5) : Color(hex: "#2A2A3E"), lineWidth: 1)
            )

            if searchFocused {
                Button("Отмена") {
                    searchText = ""
                    searchFocused = false
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(hex: "#7C5CFC"))
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3), value: searchFocused)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "server.rack")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#2A2A3E"))
            Text("Нет серверов")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Color(hex: "#444460"))
            Text("Добавьте сервер через ссылку на главной или нажмите +")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "#333350"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var serverList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(filteredServers) { server in
                    ServerRow(
                        server: server,
                        isSelected: settings.selectedServerID == server.id,
                        isConnected: vpnManager.connectionState == .connected && settings.selectedServerID == server.id
                    )
                    .onTapGesture {
                        withAnimation(.spring()) {
                            settings.selectedServerID = server.id
                        }
                    }
                    .contextMenu {
                        Button {
                            editingServer = server
                        } label: {
                            Label("Редактировать", systemImage: "pencil")
                        }
                        Button {
                            UIPasteboard.general.string = server.link
                            withAnimation { toast = ToastMessage(text: "Ссылка скопирована", style: .success) }
                        } label: {
                            Label("Копировать ссылку", systemImage: "doc.on.clipboard")
                        }
                        Divider()
                        Button(role: .destructive) {
                            withAnimation(.spring()) {
                                settings.removeServer(server)
                            }
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
    }
}

struct ServerRow: View {
    let server: ServerConfig
    let isSelected: Bool
    let isConnected: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(server.protocol.accentColor.opacity(isSelected ? 0.2 : 0.1))
                Image(systemName: server.protocol.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(server.protocol.accentColor)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(server.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    if isConnected {
                        Circle()
                            .fill(Color(hex: "#5CFC8A"))
                            .frame(width: 6, height: 6)
                            .shadow(color: Color(hex: "#5CFC8A").opacity(0.8), radius: 3)
                    }
                }
                HStack(spacing: 8) {
                    Text(server.protocol.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(server.protocol.accentColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(server.protocol.accentColor.opacity(0.12))
                        .clipShape(Capsule())

                    Text("\(server.host):\(server.port)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(Color(hex: "#666680"))
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(server.protocol.accentColor)
            } else {
                Image(systemName: "circle")
                    .font(.system(size: 20))
                    .foregroundColor(Color(hex: "#333350"))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#1A1A2E"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? server.protocol.accentColor.opacity(0.4) : Color(hex: "#2A2A3E"), lineWidth: 1)
                )
        )
        .scaleEffect(isSelected ? 1.0 : 0.998)
    }
}

struct AddServerSheet: View {
    @EnvironmentObject var settings: SettingsStore
    @Binding var toast: ToastMessage?
    @Environment(\.dismiss) var dismiss

    @State private var linkText = ""
    @FocusState private var linkFocused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0a0a10").ignoresSafeArea()
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Вставьте ссылку")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(hex: "#8A9BB8"))
                        TextEditor(text: $linkText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .background(Color(hex: "#1A1A2E"))
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(hex: "#2A2A3E"), lineWidth: 1)
                            )
                            .focused($linkFocused)
                    }

                    Text("Поддерживаются: vless://, vmess://, trojan://, ss://, hysteria2://, hy2://")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#444460"))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        if let str = UIPasteboard.general.string { linkText = str }
                    } label: {
                        Label("Вставить из буфера", systemImage: "doc.on.clipboard")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#5CF0FC"))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color(hex: "#5CF0FC").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Добавить сервер")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(Color(hex: "#8A9BB8"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Добавить") {
                        addServer()
                    }
                    .foregroundColor(Color(hex: "#7C5CFC"))
                    .fontWeight(.bold)
                    .disabled(linkText.isEmpty)
                }
            }
            .onAppear { linkFocused = true }
        }
        .preferredColorScheme(.dark)
    }

    private func addServer() {
        let links = linkText.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var added = 0
        var errors = 0
        for link in links {
            do {
                let server = try LinkParser.parse(link)
                settings.addServer(server)
                if added == 0 { settings.selectedServerID = server.id }
                added += 1
            } catch { errors += 1 }
        }
        if added > 0 {
            withAnimation { toast = ToastMessage(text: "Добавлено: \(added) \(errors > 0 ? "(ошибок: \(errors))" : "")", style: .success) }
            dismiss()
        } else {
            withAnimation { toast = ToastMessage(text: "Неверный формат ссылки", style: .error) }
        }
    }
}

struct EditServerSheet: View {
    @EnvironmentObject var settings: SettingsStore
    @Binding var toast: ToastMessage?
    @Environment(\.dismiss) var dismiss

    @State var server: ServerConfig
    @FocusState private var focusedField: EditField?

    enum EditField: Hashable { case name, host, port, uuid, password, sni }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "#0a0a10").ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        editRow("Название", value: $server.name, field: .name)
                        editRow("Хост", value: $server.host, field: .host)
                        editRowPort
                        if server.protocol != .shadowsocks && server.protocol != .hysteria2 {
                            editRow("UUID", value: Binding(
                                get: { server.uuid ?? "" },
                                set: { server.uuid = $0 }
                            ), field: .uuid)
                        }
                        if server.protocol == .trojan || server.protocol == .shadowsocks || server.protocol == .hysteria2 {
                            editRow("Пароль", value: Binding(
                                get: { server.password ?? "" },
                                set: { server.password = $0 }
                            ), field: .password)
                        }
                        editRow("SNI", value: Binding(
                            get: { server.sni ?? "" },
                            set: { server.sni = $0.isEmpty ? nil : $0 }
                        ), field: .sni)
                    }
                    .padding(20)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Готово") { focusedField = nil }
                            .foregroundColor(Color(hex: "#5CF0FC"))
                            .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                        .foregroundColor(Color(hex: "#8A9BB8"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        settings.updateServer(server)
                        withAnimation { toast = ToastMessage(text: "Сервер обновлён", style: .success) }
                        dismiss()
                    }
                    .foregroundColor(Color(hex: "#7C5CFC"))
                    .fontWeight(.bold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var editRowPort: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Порт")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#8A9BB8"))
            TextField("443", value: $server.port, format: .number)
                .keyboardType(.numberPad)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(hex: "#1A1A2E"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(hex: "#2A2A3E"), lineWidth: 1))
        }
    }

    private func editRow(_ label: String, value: Binding<String>, field: EditField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "#8A9BB8"))
            TextField(label, text: value)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($focusedField, equals: field)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color(hex: "#1A1A2E"))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(focusedField == field ? Color(hex: "#7C5CFC").opacity(0.5) : Color(hex: "#2A2A3E"), lineWidth: 1)
                )
        }
    }
}
