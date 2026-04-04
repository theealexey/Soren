import SwiftUI

// MARK: - Subscription Constellation Section

/// Animated Obsidian-style graph that maps every subscription to a glowing node.
/// Same-category services are connected with faint edges. Each node drifts
/// independently with a phase seeded from its UUID so the motion never repeats.
struct SubscriptionConstellationSection: View {
    let items: [RecurringItem]
    let onTap: (RecurringItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionHeader(String(localized: "Вселенная подписок"))
            SubscriptionConstellation(items: items, onTap: onTap)
        }
    }
}

// MARK: - Constellation Canvas

struct SubscriptionConstellation: View {
    let items: [RecurringItem]
    let onTap: (RecurringItem) -> Void

    @State private var nodes: [ConstellationNode] = []
    @State private var edges: [(Int, Int)] = []

    var body: some View {
        GeometryReader { proxy in
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                let size = proxy.size

                ZStack {
                    // ── Layer 1: edges ──────────────────────────────────────
                    Canvas { ctx, _ in
                        for (a, b) in edges {
                            guard a < nodes.count, b < nodes.count else { continue }
                            let pa = nodes[a].position(at: t, in: size)
                            let pb = nodes[b].position(at: t, in: size)
                            var path = Path()
                            path.move(to: pa)
                            path.addLine(to: pb)
                            ctx.stroke(
                                path,
                                with: .color(nodes[a].color.opacity(0.18)),
                                lineWidth: 0.6
                            )
                        }
                    }
                    .allowsHitTesting(false)

                    // ── Layer 2: nodes ──────────────────────────────────────
                    ForEach(nodes) { node in
                        let pos = node.position(at: t, in: size)
                        ConstellationNodeView(node: node)
                            .position(pos)
                            .onTapGesture { onTap(node.item) }
                    }
                }
            }
            .onAppear {
                guard nodes.isEmpty, proxy.size.width > 0 else { return }
                (nodes, edges) = buildLayout(size: proxy.size)
            }
            .onChange(of: items.count) { _, _ in
                guard proxy.size.width > 0 else { return }
                (nodes, edges) = buildLayout(size: proxy.size)
            }
        }
        .frame(height: 240)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(ColorTokens.surfaceElevated)
        )
    }

    // MARK: - Layout

    private func buildLayout(size: CGSize) -> ([ConstellationNode], [(Int, Int)]) {
        guard !items.isEmpty, size.width > 0, size.height > 0 else { return ([], []) }

        // Sort by category so same-color nodes end up near each other.
        let sorted = items.sorted { $0.category.rawValue < $1.category.rawValue }
        let total = sorted.count

        let goldenAngle = Double.pi * (3.0 - sqrt(5.0))
        let cx = size.width / 2
        let cy = size.height / 2
        let maxR = min(size.width, size.height) * 0.40

        var built: [ConstellationNode] = []
        for (i, item) in sorted.enumerated() {
            let angle = Double(i) * goldenAngle
            let r    = sqrt(Double(i + 1) / Double(total)) * maxR
            let bx   = cx + CGFloat(r * cos(angle))
            let by   = cy + CGFloat(r * sin(angle))

            let h  = abs(item.id.hashValue)
            built.append(ConstellationNode(
                item:      item,
                baseX:     bx / size.width,
                baseY:     by / size.height,
                driftPhase: Double(h % 628) / 100.0,
                driftFreq:  0.12 + Double(h % 35) / 250.0,
                driftAmp:   CGFloat(2 + h % 4)
            ))
        }

        // Edges: same-category pairs within distance threshold.
        var edgePairs: [(Int, Int)] = []
        let threshold: CGFloat = min(size.width, size.height) * 0.28
        for i in 0..<built.count {
            var connections = 0
            for j in (i + 1)..<built.count {
                guard connections < 2 else { break }
                guard built[i].item.category == built[j].item.category else { continue }
                let pi = CGPoint(x: built[i].baseX * size.width,  y: built[i].baseY * size.height)
                let pj = CGPoint(x: built[j].baseX * size.width,  y: built[j].baseY * size.height)
                if hypot(pi.x - pj.x, pi.y - pj.y) < threshold {
                    edgePairs.append((i, j))
                    connections += 1
                }
            }
        }
        return (built, edgePairs)
    }
}

// MARK: - Node Model

struct ConstellationNode: Identifiable {
    var id: UUID { item.id }
    let item: RecurringItem
    let baseX: CGFloat        // normalised 0-1
    let baseY: CGFloat
    let driftPhase: Double
    let driftFreq: Double
    let driftAmp: CGFloat

    var color: Color { item.category.color }

    func position(at t: Double, in size: CGSize) -> CGPoint {
        let ox = driftAmp * CGFloat(sin(t * driftFreq + driftPhase))
        let oy = driftAmp * CGFloat(cos(t * driftFreq * 0.7 + driftPhase + 1.2))
        return CGPoint(x: baseX * size.width + ox, y: baseY * size.height + oy)
    }
}

// MARK: - Node View

private struct ConstellationNodeView: View {
    let node: ConstellationNode

    private static let diameter: CGFloat = 11
    private static let glowRadius: CGFloat = 6

    var body: some View {
        ZStack {
            // Glow halo
            Circle()
                .fill(node.color.opacity(0.30))
                .frame(width: Self.diameter + 8, height: Self.diameter + 8)
                .blur(radius: Self.glowRadius)

            // Core dot
            Circle()
                .fill(node.color)
                .frame(width: Self.diameter, height: Self.diameter)
        }
        // Generous tap target
        .frame(width: 32, height: 32)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

#Preview {
    SubscriptionConstellationSection(
        items: [
            RecurringItem(title: "Netflix",  category: .video,        amount: 799,  nextChargeDate: .now),
            RecurringItem(title: "Spotify",  category: .music,        amount: 199,  nextChargeDate: .now),
            RecurringItem(title: "iCloud",   category: .cloud,        amount: 149,  nextChargeDate: .now),
            RecurringItem(title: "ChatGPT",  category: .aiTools,      amount: 1999, nextChargeDate: .now),
            RecurringItem(title: "YouTube",  category: .video,        amount: 299,  nextChargeDate: .now),
            RecurringItem(title: "Notion",   category: .productivity, amount: 890,  nextChargeDate: .now),
            RecurringItem(title: "1Password",category: .cloud,        amount: 350,  nextChargeDate: .now),
        ],
        onTap: { _ in }
    )
    .padding(Spacing.lg)
    .background(ColorTokens.background)
}
