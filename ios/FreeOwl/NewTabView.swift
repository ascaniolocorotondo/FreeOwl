import SwiftUI

/// La "Nuova scheda" di Free Owl: orologio, data, saluto, il gufo e la ricerca.
struct NewTabView: View {
    @EnvironmentObject private var model: BrowserModel
    @EnvironmentObject private var stats: TrackerStats
    let tab: BrowserTab
    @State private var query = ""
    @FocusState private var searching: Bool

    private static let italian = Locale(identifier: "it_IT")

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    clock(context.date)
                }
                .padding(.top, 48)

                owlRow

                searchField

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Owl.plum)
    }

    private func clock(_ date: Date) -> some View {
        VStack(spacing: 6) {
            Text(date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).locale(Self.italian)))
                .font(.system(size: 84, weight: .light))
                .monospacedDigit()
                .foregroundStyle(Owl.cream)
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Self.italian)).capitalized)
                .font(.title3)
                .foregroundStyle(Owl.creamSoft)
            Text(greeting(for: date))
                .font(.callout)
                .foregroundStyle(Owl.creamSoft)
        }
    }

    private func greeting(for date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case ..<5: return "Buonanotte, gufo notturno 🦉"
        case ..<13: return "Buongiorno"
        case ..<18: return "Buon pomeriggio"
        default: return "Buonasera"
        }
    }

    private var owlRow: some View {
        HStack(spacing: 18) {
            Image("Owl")
                .resizable()
                .scaledToFit()
                .frame(width: 96)
            VStack(alignment: .leading, spacing: 2) {
                Text("Ho bloccato")
                Text("\(stats.total) tracker")
                    .font(.title.bold())
                    .contentTransition(.numericText())
                Text("per te!")
                Text("Oggi: \(stats.today)")
                    .font(.footnote)
                    .opacity(0.75)
                    .padding(.top, 2)
            }
            .fontWeight(.semibold)
            .foregroundStyle(Owl.plum)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .background(Owl.cream, in: RoundedRectangle(cornerRadius: 18))
        }
        .animation(.default, value: stats.total)
    }

    private var searchField: some View {
        TextField("", text: $query, prompt: Text("Cerca sul web…").foregroundStyle(Owl.creamSoft))
            .focused($searching)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.webSearch)
            .submitLabel(.search)
            .foregroundStyle(Owl.cream)
            .padding(.vertical, 14)
            .padding(.horizontal, 22)
            .background(Owl.plumDark, in: Capsule())
            .overlay(Capsule().stroke(searching ? Owl.cream : Owl.plumLight, lineWidth: 2))
            .onSubmit {
                model.open(query, in: tab)
                query = ""
            }
    }
}
