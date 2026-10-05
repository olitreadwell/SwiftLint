import SwiftSyntax

@SwiftSyntaxRule(optIn: true)
struct AccessibilityTraitForButtonRule: Rule {
    var configuration = SeverityConfiguration<Self>(.warning)

    static let description = RuleDescription(
        identifier: "accessibility_trait_for_button",
        name: "Accessibility Trait for Button",
        description: "All views with tap gestures added should include the .isButton or the .isLink accessibility " +
                     "traits",
        rationale: """
        The accessibility button and link traits are used to tell assistive technologies that an element is tappable. \
        When an element has one of these traits, VoiceOver will automatically read "button" or "link" after the \
        element's label to let the user know that they can activate it.

        When using a UIKit `UIButton` or SwiftUI `Button` or `Link`, the button trait is added by default, but when \
        you manually add a tap gesture recognizer to an element, you need to explicitly add the button or link trait. \

        In most cases the button trait should be used, but for buttons that open a URL in an external browser we use \
        the link trait instead. This rule attempts to catch uses of the SwiftUI `.onTapGesture` modifier where the \
        `.isButton` or `.isLink` trait is not explicitly applied.
        """,
        kind: .lint,
        minSwiftVersion: .fiveDotOne,
        nonTriggeringExamples: AccessibilityTraitForButtonRuleExamples.nonTriggeringExamples,
        triggeringExamples: AccessibilityTraitForButtonRuleExamples.triggeringExamples
    )
}

private extension AccessibilityTraitForButtonRule {
    final class Visitor: ViolationsSyntaxVisitor<ConfigurationType> {
        private var isInViewStruct = false

        override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            isInViewStruct = node.isViewStruct
            return .visitChildren
        }

        override func visitPost(_: StructDeclSyntax) {
            isInViewStruct = false
        }

        override func visitPost(_ node: FunctionCallExprSyntax) {
            guard isInViewStruct, node.isSingleTapGestureModifier() else {
                return
            }

            // The 'node' is the tap gesture modifier itself.
            // Check if this node, any preceding modifiers in the chain, or an encapsulating Button/Link provide
            // exemption.
            if !AccessibilityButtonTraitDeterminator.isExempt(tapGestureNode: node) {
                violations.append(
                    ReasonedRuleViolation(
                        // Position of .onTapGesture etc.
                        position: node.calledExpression.positionAfterSkippingLeadingTrivia,
                        reason: AccessibilityTraitForButtonRule.description.description,
                        severity: configuration.severity
                    )
                )
            }
        }
    }
}

private struct AccessibilityButtonTraitDeterminator {
    static let maxSearchDepth = 20 // Limit for traversing up the syntax tree

    static func isExempt(tapGestureNode: FunctionCallExprSyntax) -> Bool {
        // 1. Check if accessibility traits are present anywhere in the same modifier chain
        if hasAccessibilityTraitsInChain(tapGestureNode: tapGestureNode) {
            return true
        }

        // 2. Check if the view (to which the gesture is applied) is part of an inherently exempting container
        return isInsideInherentlyExemptingContainer(startingFrom: tapGestureNode)
    }

    private static func hasAccessibilityTraitsInChain(tapGestureNode: FunctionCallExprSyntax) -> Bool {
        // Check both directions: before the tap gesture (backwards in chain) and after (ancestors in tree)

        // 1. Check backwards in the modifier chain (modifiers applied before the tap gesture)
        if hasAccessibilityTraitsBackwards(from: tapGestureNode) {
            return true
        }

        // 2. Check forwards by looking at parent nodes (modifiers applied after the tap gesture)
        return hasAccessibilityTraitsForwards(from: tapGestureNode)
    }

    private static func hasAccessibilityTraitsBackwards(from tapGestureNode: FunctionCallExprSyntax) -> Bool {
        var current: ExprSyntax? = ExprSyntax(tapGestureNode)
        var depth = 0

        while let currentExpr = current, depth < maxSearchDepth {
            defer { depth += 1 }

            if let funcCall = currentExpr.as(FunctionCallExprSyntax.self) {
                // Check if this modifier provides accessibility traits
                if funcCall.providesButtonOrLinkTrait() || funcCall.isAccessibilityHiddenTrue() {
                    return true
                }

                // Move to the previous modifier in the chain (the base of the member access)
                if let memberAccess = funcCall.calledExpression.as(MemberAccessExprSyntax.self) {
                    current = memberAccess.base
                } else {
                    // Reached the end of the chain (e.g., Text(...))
                    break
                }
            } else {
                break
            }
        }

        return false
    }

    private static func hasAccessibilityTraitsForwards(from tapGestureNode: FunctionCallExprSyntax) -> Bool {
        // Look at parent nodes to see if accessibility traits are applied after the tap gesture
        var currentNode: Syntax? = Syntax(tapGestureNode).parent
        var depth = 0

        while let node = currentNode, depth < maxSearchDepth {
            defer {
                currentNode = node.parent
                depth += 1
            }

            // Check if this parent node is a function call with accessibility traits
            if let funcCall = node.as(FunctionCallExprSyntax.self) {
                if funcCall.providesButtonOrLinkTrait() || funcCall.isAccessibilityHiddenTrue() {
                    return true
                }
            }

            // Stop at certain boundaries
            if node.is(StmtSyntax.self) || node.is(StructDeclSyntax.self) {
                break
            }
        }

        return false
    }

    private static func isInsideInherentlyExemptingContainer(startingFrom node: FunctionCallExprSyntax) -> Bool {
        var currentNode: Syntax? = Syntax(node)
        var depth = 0

        while let currentSyntaxNode = currentNode, depth < maxSearchDepth {
            defer {
                currentNode = currentSyntaxNode.parent
                depth += 1
            }

            if let funcCall = currentSyntaxNode.as(FunctionCallExprSyntax.self),
               let identifier = funcCall.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
               ["Button", "Link"].contains(identifier) {
                return true
            }

            // Stop if we reach a new View declaration or similar boundary
            if currentSyntaxNode.is(StructDeclSyntax.self) ||
                currentSyntaxNode.is(ClassDeclSyntax.self) ||
                currentSyntaxNode.is(EnumDeclSyntax.self) {
                break
            }
        }
        return false
    }

    /// Helper to check if an expression (part of a gesture modifier argument) is TapGesture(count: 1) or TapGesture()
    fileprivate static func isSingleTapGestureInstance(expression: ExprSyntax) -> Bool {
        var currentExpr: ExprSyntax? = expression

        // Traverse down if it's a chain of gesture modifiers like .onEnded to find the base gesture.
        while let memberCall = currentExpr?.as(FunctionCallExprSyntax.self), // e.g. TapGesture().onEnded()
              let memberAccess = memberCall.calledExpression.as(MemberAccessExprSyntax.self),
              memberAccess.base != nil { // Ensure it's a chain like x.method()
            currentExpr = memberAccess.base
        }

        guard let gestureCall = currentExpr?.as(FunctionCallExprSyntax.self),
              let gestureName = gestureCall.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text,
              gestureName == "TapGesture" else {
            return false
        }

        // Check count argument: TapGesture() or TapGesture(count: 1)
        if gestureCall.arguments.isEmpty { return true } // Default count is 1

        if let countArg = gestureCall.arguments.first(where: { $0.label?.text == "count" }) {
            return countArg.expression.as(IntegerLiteralExprSyntax.self)?.literal.text == "1"
        }

        // If 'count' is not specified, it defaults to 1.
        return !gestureCall.arguments.contains(where: { $0.label?.text == "count" })
    }
}

private extension StructDeclSyntax {
    var isViewStruct: Bool {
        guard let inheritanceClause else { return false }
        return inheritanceClause.inheritedTypes.contains { inheritedType in
            inheritedType.type.as(IdentifierTypeSyntax.self)?.name.text == "View"
        }
    }
}

private extension FunctionCallExprSyntax {
    func isSingleTapGestureModifier() -> Bool {
        guard let calledExpr = calledExpression.as(MemberAccessExprSyntax.self) else { return false }
        let name = calledExpr.declName.baseName.text

        if name == "onTapGesture" {
            if arguments.isEmpty { return true } // Default count is 1
            if let countArg = arguments.first(where: { $0.label?.text == "count" }) {
                return countArg.expression.as(IntegerLiteralExprSyntax.self)?.literal.text == "1"
            }
            // If 'count' is not specified, it defaults to 1 (other args like 'perform' might be present)
            return !arguments.contains(where: { $0.label?.text == "count" })
        }

        if ["gesture", "simultaneousGesture", "highPriorityGesture"].contains(name) {
            guard let firstArgExpression = arguments.first?.expression else { return false }
            return AccessibilityButtonTraitDeterminator.isSingleTapGestureInstance(expression: firstArgExpression)
        }
        return false
    }

    func providesButtonOrLinkTrait() -> Bool {
        guard let calledExpr = calledExpression.as(MemberAccessExprSyntax.self) else { return false }
        let name = calledExpr.declName.baseName.text

        if name == "accessibilityAddTraits" {
            guard let firstArgExpr = arguments.first?.expression else { return false }
            return Self.expressionContainsButtonOrLinkTrait(firstArgExpr)
        }

        if name == "accessibility" {
            guard let addTraitsArg = arguments.first(where: { $0.label?.text == "addTraits" }) else { return false }
            return Self.expressionContainsButtonOrLinkTrait(addTraitsArg.expression)
        }

        return false
    }

    private static func expressionContainsButtonOrLinkTrait(_ expression: ExprSyntax) -> Bool {
        if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            let traitName = memberAccess.declName.baseName.text
            return traitName == "isButton" || traitName == "isLink"
        }
        if let arrayExpr = expression.as(ArrayExprSyntax.self) {
            return arrayExpr.elements.contains { element in
                expressionContainsButtonOrLinkTrait(element.expression)
            }
        }
        // A ternary expression provides a trait only when both of its branches do.
        if let ternaryBranches = ternaryBranches(of: expression) {
            return ternaryBranches.allSatisfy(expressionContainsButtonOrLinkTrait)
        }
        // An `if` expression (e.g. `if #available`) provides a trait only when every branch does.
        if let ifExpr = expression.as(IfExprSyntax.self) {
            return ifExpressionProvidesButtonOrLinkTrait(ifExpr)
        }
        // Trait arrays built inside a closure, e.g. in an immediately invoked closure `{ ... }()`.
        if let statements = closureStatements(of: expression) {
            return statementsContainButtonOrLinkTrait(statements)
        }
        return false
    }

    /// Returns the branches of a ternary expression, or `nil` if the expression is not a ternary. The parser
    /// keeps `condition ? then : else` as a sequence expression holding an `UnresolvedTernaryExprSyntax` until
    /// operators are folded, so both spellings are handled.
    private static func ternaryBranches(of expression: ExprSyntax) -> [ExprSyntax]? {
        if let ternaryExpr = expression.as(TernaryExprSyntax.self) {
            return [ternaryExpr.thenExpression, ternaryExpr.elseExpression]
        }
        if let sequenceExpr = expression.as(SequenceExprSyntax.self) {
            return unresolvedTernaryBranches(of: sequenceExpr)
        }
        return nil
    }

    private static func unresolvedTernaryBranches(of sequenceExpr: SequenceExprSyntax) -> [ExprSyntax]? {
        let elements = Array(sequenceExpr.elements)
        guard let index = elements.firstIndex(where: { $0.is(UnresolvedTernaryExprSyntax.self) }),
              let ternary = elements[index].as(UnresolvedTernaryExprSyntax.self),
              elements.indices.contains(index + 1) else {
            return nil
        }
        return [ternary.thenExpression, elements[index + 1]]
    }

    /// An `if` expression provides a trait only when its body and every `else` branch do. An `if` without an
    /// `else` branch may not provide the trait at all.
    private static func ifExpressionProvidesButtonOrLinkTrait(_ ifExpr: IfExprSyntax) -> Bool {
        guard statementsContainButtonOrLinkTrait(ifExpr.body.statements) else {
            return false
        }
        switch ifExpr.elseBody {
        case .codeBlock(let elseBlock):
            return statementsContainButtonOrLinkTrait(elseBlock.statements)
        case .ifExpr(let elseIfExpr):
            return ifExpressionProvidesButtonOrLinkTrait(elseIfExpr)
        case .none:
            return false
        }
    }

    private static func closureStatements(of expression: ExprSyntax) -> CodeBlockItemListSyntax? {
        if let closureExpr = expression.as(ClosureExprSyntax.self) {
            return closureExpr.statements
        }
        if let callExpr = expression.as(FunctionCallExprSyntax.self),
           let closureExpr = callExpr.calledExpression.as(ClosureExprSyntax.self) {
            return closureExpr.statements
        }
        return nil
    }

    private static func statementsContainButtonOrLinkTrait(_ statements: CodeBlockItemListSyntax) -> Bool {
        statements.contains { item in
            switch item.item {
            case .expr(let expression):
                return expressionContainsButtonOrLinkTrait(expression)
            case .stmt(let statement):
                return statementProvidesButtonOrLinkTrait(statement)
            case .decl:
                return false
            }
        }
    }

    private static func statementProvidesButtonOrLinkTrait(_ statement: StmtSyntax) -> Bool {
        if let expressionStmt = statement.as(ExpressionStmtSyntax.self) {
            return expressionContainsButtonOrLinkTrait(expressionStmt.expression)
        }
        if let returnStmt = statement.as(ReturnStmtSyntax.self), let returnValue = returnStmt.expression {
            return expressionContainsButtonOrLinkTrait(returnValue)
        }
        return false
    }

    func isAccessibilityHiddenTrue() -> Bool {
        guard let calledExpr = calledExpression.as(MemberAccessExprSyntax.self) else { return false }
        let name = calledExpr.declName.baseName.text

        if name == "accessibilityHidden" {
            return arguments.first?.expression.as(BooleanLiteralExprSyntax.self)?.literal.tokenKind == .keyword(.true)
        }

        if name == "accessibility" {
            guard let hiddenArg = arguments.first(where: { $0.label?.text == "hidden" }) else { return false }
            return hiddenArg.expression.as(BooleanLiteralExprSyntax.self)?.literal.tokenKind == .keyword(.true)
        }

        return false
    }
}
