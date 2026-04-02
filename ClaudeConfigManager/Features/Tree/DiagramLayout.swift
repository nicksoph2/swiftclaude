import SwiftUI

/// Fixed layout positions for the eight pipeline nodes arranged in a U-shape:
///
/// ```
/// Row 1: Discovery → Parsing → Resolution → Prompt Assembly
///                                                          ↓
/// Row 2: Context Budget ← MCP Servers ← Hooks Lifecycle ← Tool Execution
/// ```
///
/// All coordinates are expressed in a design coordinate space of `designSize`
/// and scaled proportionally when the container is narrower.
enum DiagramLayout {

    // MARK: - Design Constants

    /// The reference design size (fits a 13″ MacBook content area).
    static let designSize = CGSize(width: 880, height: 340)

    /// Node card size.
    static let nodeSize = CGSize(width: 160, height: 90)

    /// Vertical centre of row 1.
    private static let row1Y: CGFloat = 55

    /// Vertical centre of row 2.
    private static let row2Y: CGFloat = 250

    /// Horizontal positions for columns 1–4 (centred within the design width).
    private static let columnXs: [CGFloat] = [100, 310, 520, 730]

    // MARK: - Node Positions

    /// Returns the centre point for every pipeline stage in the design coordinate space.
    static let nodePositions: [PipelineStage: CGPoint] = {
        var map = [PipelineStage: CGPoint]()

        // Row 1: left to right
        let row1Stages: [PipelineStage] = [.discovery, .parsing, .resolution, .promptAssembly]
        for (i, stage) in row1Stages.enumerated() {
            map[stage] = CGPoint(x: columnXs[i], y: row1Y)
        }

        // Row 2: right to left (reversed column order)
        let row2Stages: [PipelineStage] = [.toolExecution, .hooksLifecycle, .mcpServers, .contextBudget]
        for (i, stage) in row2Stages.enumerated() {
            map[stage] = CGPoint(x: columnXs[3 - i], y: row2Y)
        }

        return map
    }()

    // MARK: - Ordered Connections

    /// The ordered pipeline flow used to draw arrows.
    /// Each pair `(from, to)` represents one connection.
    static let connections: [(from: PipelineStage, to: PipelineStage)] = [
        (.discovery, .parsing),
        (.parsing, .resolution),
        (.resolution, .promptAssembly),
        (.promptAssembly, .toolExecution),   // vertical drop
        (.toolExecution, .hooksLifecycle),
        (.hooksLifecycle, .mcpServers),
        (.mcpServers, .contextBudget),
    ]

    // MARK: - Arrow Path Builder

    /// Builds a `Path` for the arrow connecting two stages.
    ///
    /// Horizontal neighbours use a gentle quad-curve; the vertical drop
    /// between rows uses a smooth S-curve.
    static func arrowPath(from src: PipelineStage, to dst: PipelineStage) -> Path {
        guard let srcPt = nodePositions[src],
              let dstPt = nodePositions[dst] else {
            return Path()
        }

        let halfW = nodeSize.width / 2
        let halfH = nodeSize.height / 2

        // Determine anchor points on card edges.
        let start: CGPoint
        let end: CGPoint

        let isVertical = (src == .promptAssembly && dst == .toolExecution)
        let isRow2 = (srcPt.y == row2Y && dstPt.y == row2Y)

        if isVertical {
            // Vertical: exit bottom of src, enter top of dst
            start = CGPoint(x: srcPt.x, y: srcPt.y + halfH)
            end   = CGPoint(x: dstPt.x, y: dstPt.y - halfH)
        } else if isRow2 {
            // Row 2 flows right-to-left: exit left of src, enter right of dst
            start = CGPoint(x: srcPt.x - halfW, y: srcPt.y)
            end   = CGPoint(x: dstPt.x + halfW, y: dstPt.y)
        } else {
            // Row 1 flows left-to-right: exit right of src, enter left of dst
            start = CGPoint(x: srcPt.x + halfW, y: srcPt.y)
            end   = CGPoint(x: dstPt.x - halfW, y: dstPt.y)
        }

        var path = Path()
        path.move(to: start)

        if isVertical {
            // S-curve for the vertical drop
            let midY = (start.y + end.y) / 2
            path.addCurve(
                to: end,
                control1: CGPoint(x: start.x, y: midY),
                control2: CGPoint(x: end.x, y: midY)
            )
        } else {
            // Gentle quad-curve for horizontal connections
            let midX = (start.x + end.x) / 2
            let curveOffset: CGFloat = 8
            let controlY = start.y - curveOffset
            path.addQuadCurve(to: end, control: CGPoint(x: midX, y: controlY))
        }

        return path
    }

    /// Builds a small filled-triangle arrowhead at the **end** of the given connection.
    static func arrowheadPath(from src: PipelineStage, to dst: PipelineStage) -> Path {
        guard let srcPt = nodePositions[src],
              let dstPt = nodePositions[dst] else {
            return Path()
        }

        let halfW = nodeSize.width / 2
        let halfH = nodeSize.height / 2
        let size: CGFloat = 6

        let isVertical = (src == .promptAssembly && dst == .toolExecution)
        let isRow2 = (srcPt.y == row2Y && dstPt.y == row2Y)

        let tip: CGPoint
        let angle: Angle // direction the triangle points

        if isVertical {
            tip = CGPoint(x: dstPt.x, y: dstPt.y - halfH)
            angle = .degrees(90)
        } else if isRow2 {
            tip = CGPoint(x: dstPt.x + halfW, y: dstPt.y)
            angle = .degrees(180)
        } else {
            tip = CGPoint(x: dstPt.x - halfW, y: dstPt.y)
            angle = .degrees(0)
        }

        return trianglePath(at: tip, size: size, angle: angle)
    }

    /// Equilateral triangle pointing in the given direction.
    private static func trianglePath(at tip: CGPoint, size: CGFloat, angle: Angle) -> Path {
        let rad = angle.radians
        let halfBase = size * 0.6

        // Tip is the forward vertex; base vertices are behind it.
        let backCentre = CGPoint(
            x: tip.x - size * cos(rad),
            y: tip.y - size * sin(rad)
        )
        let perpX = -sin(rad)
        let perpY =  cos(rad)

        let left  = CGPoint(x: backCentre.x + halfBase * perpX,
                            y: backCentre.y + halfBase * perpY)
        let right = CGPoint(x: backCentre.x - halfBase * perpX,
                            y: backCentre.y - halfBase * perpY)

        var path = Path()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    // MARK: - Arrow Midpoint

    /// Returns the approximate midpoint of the arrow connecting two stages.
    ///
    /// Used to position health propagation dots. For horizontal connections the
    /// midpoint is the mid-X of the straight segment; for the vertical drop it is
    /// the geometric centre of the S-curve.
    static func arrowMidpoint(from src: PipelineStage, to dst: PipelineStage) -> CGPoint? {
        guard let srcPt = nodePositions[src],
              let dstPt = nodePositions[dst] else { return nil }

        let halfW = nodeSize.width / 2
        let halfH = nodeSize.height / 2

        let isVertical = (src == .promptAssembly && dst == .toolExecution)
        let isRow2     = (srcPt.y == row2Y && dstPt.y == row2Y)

        if isVertical {
            // Mid-way down the S-curve
            let startY = srcPt.y + halfH
            let endY   = dstPt.y - halfH
            return CGPoint(x: srcPt.x, y: (startY + endY) / 2)
        } else if isRow2 {
            let startX = srcPt.x - halfW
            let endX   = dstPt.x + halfW
            return CGPoint(x: (startX + endX) / 2, y: srcPt.y)
        } else {
            let startX = srcPt.x + halfW
            let endX   = dstPt.x - halfW
            return CGPoint(x: (startX + endX) / 2, y: srcPt.y - 8)
        }
    }

    // MARK: - Scaling

    /// Returns the uniform scale factor for the given container size.
    static func scaleFactor(for containerSize: CGSize) -> CGFloat {
        let sx = containerSize.width  / designSize.width
        let sy = containerSize.height / designSize.height
        return min(sx, sy, 1.0)   // never scale up, only down
    }
}
