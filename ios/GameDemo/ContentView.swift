import SwiftUI

/// UI only. All rules live in the Rust `Game` object (generated bindings in Generated/game_core.swift).
struct ContentView: View {
    @State private var game = Game(seed: 42)
    @State private var cells: [UInt32] = []
    @State private var score: UInt32 = 0
    @State private var over = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Rust core · SwiftUI UI").font(.headline)
            Text("Score \(score)").font(.largeTitle.bold()).monospacedDigit()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 8) {
                ForEach(0..<16, id: \.self) { i in
                    Tile(value: i < cells.count ? cells[i] : 0)
                }
            }
            .padding(8)
            .background(Color(white: 0.75), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            .gesture(DragGesture(minimumDistance: 20).onEnded { v in
                let dx = v.translation.width, dy = v.translation.height
                move(abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up))
            })

            if over { Text("Game over").foregroundStyle(.red).font(.title2.bold()) }
            Button("New game") { game = Game(seed: UInt64.random(in: 1...UInt64.max)); refresh() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .onAppear {
            refresh()
            // Debug aid for screenshots: launch with `-autoplay N` to make N scripted moves.
            let args = ProcessInfo.processInfo.arguments
            if let k = args.firstIndex(of: "-autoplay"), k + 1 < args.count, let n = Int(args[k + 1]) {
                let order: [Direction] = [.left, .up, .right, .down]
                for step in 0..<n { move(order[step % 4]) }
            }
        }
    }

    private func move(_ d: Direction) {
        _ = game.slide(dir: d)
        refresh()
    }

    private func refresh() {
        cells = game.cells()
        score = game.score()
        over = game.isOver()
    }
}

struct Tile: View {
    let value: UInt32

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(color)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if value != 0 {
                    Text("\(value)")
                        .font(.title.bold())
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(value <= 4 ? Color(white: 0.2) : .white)
                }
            }
    }

    private var color: Color {
        switch value {
        case 0: return Color(white: 0.85)
        case 2: return Color(red: 0.93, green: 0.89, blue: 0.85)
        case 4: return Color(red: 0.93, green: 0.88, blue: 0.78)
        case 8: return Color(red: 0.95, green: 0.69, blue: 0.47)
        case 16: return Color(red: 0.96, green: 0.58, blue: 0.39)
        case 32: return Color(red: 0.96, green: 0.49, blue: 0.37)
        case 64: return Color(red: 0.96, green: 0.37, blue: 0.23)
        default: return Color(red: 0.93, green: 0.81, blue: 0.45)
        }
    }
}
