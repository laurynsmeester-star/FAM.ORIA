//
//  FamilyTreeConnections.swift
//  Famoria 2026
//
//  Renders the lines between nodes on the family tree canvas.
//
//  - Spouse lines: thin horizontal segment between the two cards' centers.
//  - Parent → child lines: orthogonal "elbow" — straight down from parents'
//    bottom-center to a horizontal "bus" at half the gap, then straight down
//    to each child's top-center.
//

import SwiftUI

struct FamilyTreeConnectionsView: View {

    let connections: [ConnectionLine]

    var body: some View {
        Canvas { context, _ in
            for line in connections {
                switch line.kind {
                case .spouse:
                    drawSpouse(context: context, line: line)
                case .parentChild:
                    drawParentChild(context: context, line: line)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func drawSpouse(context: GraphicsContext, line: ConnectionLine) {
        var path = Path()
        path.move(to: line.from)
        path.addLine(to: line.to)
        context.stroke(
            path,
            with: .color(Color.pink.opacity(0.55)),
            style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
        )
    }

    private func drawParentChild(context: GraphicsContext, line: ConnectionLine) {
        var path = Path()
        if let drop = line.drop {
            // Parent bottom → drop intermediate → child top, orthogonal elbow.
            path.move(to: line.from)
            path.addLine(to: CGPoint(x: line.from.x, y: drop.y))
            path.addLine(to: CGPoint(x: drop.x, y: drop.y))
            path.addLine(to: line.to)
        } else {
            path.move(to: line.from)
            path.addLine(to: line.to)
        }
        context.stroke(
            path,
            with: .color(Color.gray.opacity(0.55)),
            style: StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
        )
    }
}
