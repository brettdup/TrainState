import SwiftUI

// MARK: - Wrapping HStack Layout
struct WrappingHStackLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = 8, verticalSpacing: CGFloat = 8) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }
    
    private func computeRows(subviews: Subviews, proposalWidth: CGFloat) -> (rows: [[LayoutSubview]], subviewSizes: [CGSize]) {
        var rows: [[LayoutSubview]] = []
        var currentRow: [LayoutSubview] = []
        var currentRowWidth: CGFloat = 0
        let subviewSizes = subviews.map { $0.sizeThatFits(.unspecified) }

        for (index, subview) in subviews.enumerated() {
            let subviewSize = subviewSizes[index]
            if currentRowWidth + subviewSize.width + (currentRow.isEmpty ? 0 : horizontalSpacing) > proposalWidth && !currentRow.isEmpty {
                rows.append(currentRow)
                currentRow = []
                currentRowWidth = 0
            }
            currentRow.append(subview)
            currentRowWidth += subviewSize.width + (currentRow.count > 1 ? horizontalSpacing : 0)
        }
        if !currentRow.isEmpty {
            rows.append(currentRow)
        }
        return (rows, subviewSizes)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard !subviews.isEmpty else { return .zero }

        let effectiveProposalWidth = proposal.width ?? .infinity 
        let (rows, subviewSizes) = computeRows(subviews: subviews, proposalWidth: effectiveProposalWidth)

        let totalHeight = rows.enumerated().reduce(CGFloat.zero) { accumulatedHeight, rowData in
            let (rowIndex, rowViews) = rowData
            let rowHeight = rowViews.map { subview -> CGFloat in
                let subviewIndex = subviews.firstIndex(of: subview)!
                return subviewSizes[subviewIndex].height
            }.max() ?? 0
            return accumulatedHeight + (rowIndex > 0 ? verticalSpacing : 0) + rowHeight
        }

        let maxWidth = rows.reduce(CGFloat.zero) { currentMaxWidth, rowViews in
            let rowWidth = rowViews.enumerated().reduce(CGFloat.zero) { accumulatedWidth, viewData in
                let (viewIndex, view) = viewData
                let subviewIndex = subviews.firstIndex(of: view)!
                return accumulatedWidth + (viewIndex > 0 ? horizontalSpacing : 0) + subviewSizes[subviewIndex].width
            }
            return max(currentMaxWidth, rowWidth)
        }
        
        return CGSize(width: proposal.width ?? maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard !subviews.isEmpty else { return }
        
        let (rows, subviewSizes) = computeRows(subviews: subviews, proposalWidth: bounds.width)
        var currentY = bounds.minY

        for (rowIndex, rowViews) in rows.enumerated() {
            var currentX = bounds.minX
            let rowHeight = rowViews.map { subview -> CGFloat in
                let subviewIndex = subviews.firstIndex(of: subview)!
                return subviewSizes[subviewIndex].height
            }.max() ?? 0
            
            if rowIndex > 0 {
                currentY += verticalSpacing
            }

            for (viewIndex, view) in rowViews.enumerated() {
                if viewIndex > 0 {
                    currentX += horizontalSpacing
                }
                let subviewIndex = subviews.firstIndex(of: view)!
                let currentSubviewSize = subviewSizes[subviewIndex]
                
                view.place(at: CGPoint(x: currentX, y: currentY),
                           anchor: .topLeading,
                           proposal: ProposedViewSize(currentSubviewSize))
                
                currentX += currentSubviewSize.width
            }
            currentY += rowHeight
        }
    }
} 