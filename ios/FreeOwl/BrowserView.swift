import SwiftUI
import WebKit

struct BrowserView: View {
    @EnvironmentObject private var model: BrowserModel

    var body: some View {
        ZStack {
            Owl.plum.ignoresSafeArea()
            if let tab = model.current {
                TabScreen(tab: tab)
                    .id(tab.id)
            }
        }
    }
}

/// Mostra la WKWebView della scheda dentro SwiftUI.
private struct WebViewContainer: UIViewRepresentable {
    let webView: WKWebView
    func makeUIView(context: Context) -> WKWebView { webView }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// Una scheda a schermo: la pagina (o la Nuova scheda) e la barra in basso.
private struct TabScreen: View {
    @EnvironmentObject private var model: BrowserModel
    @ObservedObject var tab: BrowserTab

    @State private var address = ""
    @FocusState private var editing: Bool
    @State private var showTabs = false
    @State private var confirmFlyAway = false
    @State private var toast: String?

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                if tab.showsNewTab {
                    NewTabView(tab: tab)
                } else {
                    WebViewContainer(webView: tab.webView)
                        .ignoresSafeArea(.container, edges: .top)
                }
                if tab.isLoading && !tab.showsNewTab {
                    ProgressView(value: tab.progress)
                        .tint(Owl.cream)
                        .progressViewStyle(.linear)
                }
                if let message = tab.errorMessage, !tab.showsNewTab {
                    errorBanner(message)
                }
            }
            .frame(maxHeight: .infinity)
            .overlay(alignment: .bottom) { toastView }

            bottomBar
        }
        .sheet(isPresented: $showTabs) {
            TabsSheet()
        }
        .confirmationDialog("Vola via?", isPresented: $confirmFlyAway, titleVisibility: .visible) {
            Button("🪶 Cancella tutto", role: .destructive) {
                Task {
                    await model.flyAway()
                }
            }
        } message: {
            Text("Cancello cookie, cronologia, cache e chiudo tutte le schede. Le password salvate su iPhone restano.")
        }
    }

    // MARK: Barra in basso

    private var bottomBar: some View {
        VStack(spacing: 10) {
            addressField
            HStack {
                barButton("chevron.backward", enabled: tab.canGoBack || !tab.showsNewTab) { tab.goBack() }
                Spacer()
                barButton("chevron.forward", enabled: tab.canGoForward || (tab.showsNewTab && tab.webView.url != nil)) {
                    tab.goForward()
                }
                Spacer()
                Button {
                    model.newTab()
                } label: {
                    Image(systemName: "plus").font(.title3)
                }
                .accessibilityLabel("Nuova scheda")
                Spacer()
                Button {
                    showTabs = true
                } label: {
                    Text("\(model.tabs.count)")
                        .font(.footnote.bold())
                        .frame(width: 24, height: 24)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(lineWidth: 2))
                }
                .accessibilityLabel("Schede aperte: \(model.tabs.count)")
                Spacer()
                menu
            }
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .foregroundStyle(Owl.cream)
        .background(Owl.plumDark)
    }

    private func barButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.title3)
        }
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    private var addressField: some View {
        HStack(spacing: 8) {
            if !tab.showsNewTab && !editing {
                Label("\(tab.blockedOnPage)", systemImage: tab.blockedOnPage > 0 ? "shield.lefthalf.filled" : "shield")
                    .font(.footnote.bold())
                    .labelStyle(.titleAndIcon)
                    .foregroundStyle(tab.blockedOnPage > 0 ? Owl.orange : Owl.creamSoft)
                    .accessibilityLabel("Tracker bloccati in questa pagina: \(tab.blockedOnPage)")
            }
            TextField("", text: $address, prompt: Text("Cerca o scrivi un indirizzo").foregroundStyle(Owl.creamSoft))
                .focused($editing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.webSearch)
                .submitLabel(.go)
                .multilineTextAlignment(editing ? .leading : .center)
                .onSubmit {
                    model.open(address, in: tab)
                    editing = false
                }
            if editing && !address.isEmpty {
                Button {
                    address = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Owl.creamSoft)
                }
            } else if !tab.showsNewTab && !editing {
                Button {
                    if tab.isLoading {
                        tab.webView.stopLoading()
                    } else {
                        tab.webView.reload()
                    }
                } label: {
                    Image(systemName: tab.isLoading ? "xmark" : "arrow.clockwise")
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Owl.plum, in: Capsule())
        .overlay(Capsule().stroke(editing ? Owl.cream : Owl.plumLight, lineWidth: 1.5))
        .onAppear(perform: syncAddress)
        .onChange(of: tab.url) { syncAddress() }
        .onChange(of: tab.showsNewTab) { syncAddress() }
        .onChange(of: editing) {
            if editing {
                address = tab.showsNewTab ? "" : (tab.url?.absoluteString ?? "")
            } else {
                syncAddress()
            }
        }
    }

    private func syncAddress() {
        guard !editing else { return }
        if tab.showsNewTab {
            address = ""
        } else {
            let host = tab.url?.host() ?? ""
            address = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        }
    }

    private var menu: some View {
        Menu {
            Button {
                model.nightMode.toggle()
                showToast(model.nightMode ? "🌙 Modalità Notte attiva" : "☀️ Modalità Notte spenta")
            } label: {
                Label(model.nightMode ? "Spegni Modalità Notte" : "Modalità Notte", systemImage: "moon")
            }
            Picker(selection: $model.engine) {
                ForEach(SearchEngine.allCases) { engine in
                    Text(engine.name).tag(engine)
                }
            } label: {
                Label("Motore di ricerca", systemImage: "magnifyingglass")
            }
            .pickerStyle(.menu)
            if !tab.showsNewTab, let url = tab.url {
                ShareLink(item: url) {
                    Label("Condividi", systemImage: "square.and.arrow.up")
                }
            }
            Divider()
            Button(role: .destructive) {
                confirmFlyAway = true
            } label: {
                Label("Vola via", systemImage: "wind")
            }
        } label: {
            Image(systemName: "ellipsis.circle").font(.title3)
        }
        .accessibilityLabel("Menu")
    }

    // MARK: Messaggi

    private func errorBanner(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image("Owl").resizable().scaledToFit().frame(width: 70)
            Text("Ops, il gufo non riesce ad aprire la pagina").font(.headline)
            Text(message).font(.footnote).multilineTextAlignment(.center).opacity(0.8)
            Button("Riprova") { tab.webView.reload() }
                .buttonStyle(.borderedProminent)
                .tint(Owl.cream)
                .foregroundStyle(Owl.plum)
        }
        .foregroundStyle(Owl.cream)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Owl.plum)
    }

    @ViewBuilder
    private var toastView: some View {
        if let toast {
            Text(toast)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Owl.plum)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Owl.cream, in: Capsule())
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func showToast(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { if toast == text { toast = nil } }
        }
    }
}

/// L'elenco delle schede aperte.
private struct TabsSheet: View {
    @EnvironmentObject private var model: BrowserModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.tabs) { tab in
                    TabRow(tab: tab, isCurrent: tab.id == model.currentID)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            model.select(tab)
                            dismiss()
                        }
                        .swipeActions {
                            Button("Chiudi", role: .destructive) { model.close(tab) }
                        }
                        .listRowBackground(Owl.plumDark)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Owl.plum)
            .navigationTitle("Schede")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        model.newTab()
                        dismiss()
                    } label: {
                        Label("Nuova scheda", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fine") { dismiss() }
                }
            }
        }
        .tint(Owl.cream)
        .presentationDetents([.medium, .large])
    }
}

private struct TabRow: View {
    @EnvironmentObject private var model: BrowserModel
    @ObservedObject var tab: BrowserTab
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tab.showsNewTab ? "sparkles" : "globe")
                .foregroundStyle(Owl.creamSoft)
            VStack(alignment: .leading, spacing: 2) {
                Text(tab.displayTitle)
                    .lineLimit(1)
                    .fontWeight(isCurrent ? .bold : .regular)
                if !tab.showsNewTab, let host = tab.url?.host() {
                    Text(host).font(.caption).foregroundStyle(Owl.creamSoft).lineLimit(1)
                }
            }
            Spacer()
            Button {
                model.close(tab)
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(Owl.creamSoft)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Chiudi scheda")
        }
        .foregroundStyle(Owl.cream)
    }
}
