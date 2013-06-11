// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

part of parser;

// TODO(terry): Detect invalid directive usage.  All @imports must occur before
//              all rules other than @charset directive.  Any @import directive
//              after any non @charset or @import directive are ignored. e.g.,
//                  @import "a.css";
//                  div { color: red; }
//                  @import "b.css";
//              becomes:
//                  @import "a.css";
//                  div { color: red; }
// <http://www.w3.org/TR/css3-syntax/#at-rules>

/**
 * Analysis phase will validate/fixup any new CSS feature or any SASS style
 * feature.
 */
class Analyzer {
  final List<StyleSheet> _styleSheets;
  final Messages _messages;
  VarDefinitions varDefs;

  Analyzer(this._styleSheets, this._messages);

  void run({bool nested: false}) {
    varDefs = new VarDefinitions(_styleSheets);

    // Any cycles?
    var cycles = findAllCycles();
    for (var cycle in cycles) {
      _messages.warning("var cycle detected var-${cycle.definedName}",
          cycle.span);
      // TODO(terry): What if no var definition for a var usage an error?
      // TODO(terry): Ensure a var definition imported from a different style
      //              sheet works.
    }

    // Remove any var definition from the stylesheet that has a cycle.
    _styleSheets.forEach((styleSheet) =>
        new RemoveVarDefinitions(cycles).visitStyleSheet(styleSheet));

    // Expand any nested selectors using selector desendant combinator to
    // signal CSS inheritance notation.
    if (nested) {
      _styleSheets.forEach((styleSheet) => new ExpandNestedSelectors()
          ..visitStyleSheet(styleSheet)
          ..flatten(styleSheet));
    }
  }

  List<VarDefinition> findAllCycles() {
    var cycles = [];

    varDefs.map.values.forEach((value) {
      if (hasCycle(value.property)) cycles.add(value);
     });

    // Update our local list of known varDefs remove any varDefs with a cycle.
    // So the same varDef cycle isn't reported for each style sheet processed.
    for (var cycle in cycles) {
      varDefs.map.remove(cycle.property);
    }

    return cycles;
  }

  Iterable<VarUsage> variablesOf(Expressions exprs) =>
      exprs.expressions.where((e) => e is VarUsage);

  bool hasCycle(String varName, {Set<String> visiting, Set<String> visited}) {
    if (visiting == null) visiting = new Set();
    if (visited == null) visited = new Set();
    if (visiting.contains(varName)) return true;
    if (visited.contains(varName)) return false;
    visiting.add(varName);
    visited.add(varName);
    bool cycleDetected = false;
    if (varDefs.map[varName] != null) {
      for (var usage in variablesOf(varDefs.map[varName].expression)) {
        if (hasCycle(usage.name, visiting: visiting, visited: visited)) {
          cycleDetected = true;
          break;
        }
      }
    }
    visiting.remove(varName);
    return cycleDetected;
  }

  // TODO(terry): Need to start supporting @host, custom pseudo elements,
  //              composition, intrinsics, etc.
}


/** Find all var definitions from a list of stylesheets. */
class VarDefinitions extends Visitor {
  /** Map of variable name key to it's definition. */
  final Map<String, VarDefinition> map = new Map<String, VarDefinition>();

  VarDefinitions(List<StyleSheet> styleSheets) {
    for (var styleSheet in styleSheets) {
      visitTree(styleSheet);
    }
  }

  void visitVarDefinition(VarDefinition node) {
    // Replace with latest variable definition.
    map[node.definedName] = node;
    super.visitVarDefinition(node);
  }

  void visitVarDefinitionDirective(VarDefinitionDirective node) {
    visitVarDefinition(node.def);
  }
}

/**
 * Remove the var definition from the stylesheet where it is defined; if it is
 * a definition from the list to delete.
 */
class RemoveVarDefinitions extends Visitor {
  final List<VarDefinition> _varDefsToRemove;

  RemoveVarDefinitions(this._varDefsToRemove);

  void visitStyleSheet(StyleSheet ss) {
    var idx = ss.topLevels.length;
    while(--idx >= 0) {
      var topLevel = ss.topLevels[idx];
      if (topLevel is VarDefinitionDirective &&
          _varDefsToRemove.contains(topLevel.def)) {
        ss.topLevels.removeAt(idx);
      }
    }

    super.visitStyleSheet(ss);
  }

  void visitDeclarationGroup(DeclarationGroup node) {
    var idx = node.declarations.length;
    while (--idx >= 0) {
      var decl = node.declarations[idx];
      if (decl is VarDefinition && _varDefsToRemove.contains(decl)) {
        node.declarations.removeAt(idx);
      }
    }

    super.visitDeclarationGroup(node);
  }
}

/**
 * Traverse all rulesets looking for nested ones.  If a ruleset is in a
 * declaration group (implies nested selector) then generate new ruleset(s) at
 * level 0 of CSS using selector inheritance syntax (flattens the nesting).
 */
class ExpandNestedSelectors extends Visitor {
  /** Parent [RuleSet] if a nested selectors otherwise [null]. */
  RuleSet _parentRuleSet;

  /** Flatten nested selectors to one selector using descendant combinator. */
  List<SelectorGroup> _flatSelectors = [];

  /** List of all declarations (sans the nested selectors). */
  List<DeclarationGroup> _flatDeclarationGroup = [];

  /** Each nested selector get's a flatten RuleSet. */
  List<RuleSet> _expandedRuleSets = [];

  /** Maping of a nested rule set to the fully expanded list of RuleSet(s). */
  final Map<RuleSet, List<RuleSet>> _expansions = new Map();

  void visitRuleSet(RuleSet node) {
    var oldParentRuleSet = _parentRuleSet;
    _parentRuleSet = node;

    final newSelectors = node.selectorGroup.selectors.toList();

    _flatSelectors.add(new SelectorGroup(newSelectors, node.span));

    super.visitRuleSet(node);

    assert(_parentRuleSet == node);

    _parentRuleSet = oldParentRuleSet;

    // If any expandedRuleSets and we're back at the top-level rule set then
    // there were nested rule set(s).
    if (_parentRuleSet == null) {
      if (!_expandedRuleSets.isEmpty && _flatSelectors.isEmpty) {
        // Remember ruleset to replace with these flattened rulesets.
        _expansions[node] = _expandedRuleSets;
        _expandedRuleSets = [];
      } else {
        _flatDeclarationGroup = [];
        _flatSelectors = [];
      }
    }
  }

  // TODO(terry): Need to introduce a new node to the AST for a nested rule for
  //              a declaration group.  This in conjunction with selector
  //              expressions having a separate combinator operator instead of
  //              the selector and combinator being the same node will help
  //              in understanding what is happening as the nested rules are
  //              flattened.
  void visitDeclarationGroup(DeclarationGroup node) {
    var span = node.span;
    _flatDeclarationGroup.add(new DeclarationGroup([], span));

    super.visitDeclarationGroup(node);

    // No rule to process (it's a directive).
    if (_parentRuleSet == null) return;

    var expandedSelectors = [];

    _flatSelectors.forEach((group) => group.selectors.forEach((selectors) {
      var selectorSeqs = selectors.simpleSelectorSequences;

      // More than one selectors in group then it's a nested selector.
      if (!expandedSelectors.isEmpty) {
        // Selector is nested so make the first simple selector a descendant.
        var first = selectorSeqs.first;
        var newSeq = new SimpleSelectorSequence(first.simpleSelector,
            first.span, TokenKind.COMBINATOR_DESCENDANT);
        // Replace first SimpleSelectorSequence with descendant combinator.
        selectorSeqs.replaceRange(0, 1, [newSeq]);
      }
      // Use our nested simple selectors as a descendent.
      expandedSelectors.addAll(selectorSeqs);
    }));

    _flatSelectors.removeLast();
    var declarationGroup = _flatDeclarationGroup.removeLast();

    // Build are new rule set from the nested selectors and declarations.
    var selector = new Selector(expandedSelectors, span);
    var selectorGroup = new SelectorGroup([selector], span);
    var newRuleSet = new RuleSet(selectorGroup, declarationGroup, span);

    // Place in order so outer-most rule is first.
    _expandedRuleSets.insert(0, newRuleSet);
  }

  // Record all declarations in a nested selector (Declaration, VarDefinition
  // and MarginGroup).

  void visitDeclaration(Declaration node) {
    if (_parentRuleSet != null) {
      _flatDeclarationGroup.last.declarations.add(node);
    }
    super.visitDeclaration(node);
  }

  void visitVarDefinition(VarDefinition node) {
    if (_parentRuleSet != null) {
      _flatDeclarationGroup.last.declarations.add(node);
    }
    super.visitVarDefinition(node);
  }

  void visitMarginGroup(MarginGroup node) {
    if (_parentRuleSet != null) {
      _flatDeclarationGroup.last.declarations.add(node);
    }
    super.visitMarginGroup(node);
  }

  /**
   * Replace the rule set that contains nested rules with the flatten rule sets.
   */
  void flatten(StyleSheet styleSheet) {
    // TODO(terry): Iterate over topLevels instead of _expansions it's already
    //              a map (this maybe quadratic).
    _expansions.forEach((RuleSet ruleSet, List<RuleSet> newRules) {
      var index = styleSheet.topLevels.indexOf(ruleSet);
      if (index != -1) {
        styleSheet.topLevels.replaceRange(index, index + 1, newRules);
      }
    });
  }
}
