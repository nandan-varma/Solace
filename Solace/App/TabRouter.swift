//
//  TabRouter.swift
//  Solace
//

import Observation

enum AppTab: Hashable {
    case today, scan, trends, settings
}

/// Lets any screen request a *tab switch* rather than pushing a nested copy
/// of another tab's root view onto its own NavigationStack (e.g. Today's
/// "Scan" quick action should activate the Scan tab, not open a second,
/// back-buttoned Scan screen inside Today).
@Observable
final class TabRouter {
    var selected: AppTab = .today
}
