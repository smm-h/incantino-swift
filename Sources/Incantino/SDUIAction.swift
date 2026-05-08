// SDUIAction.swift
// Standard SDUI action type identifiers.

/// Enumeration of standard SDUI action types.
/// Each case corresponds to an action the engine can dispatch.
public enum SDUIAction: String, Sendable, CaseIterable {
    case navigate
    case message
    case toast
    case openURL
    case camera
    case gallery
    case sheetOpen = "sheet.open"
    case sheetDismiss = "sheet.dismiss"
    case flowNext = "flow.next"
    case flowBack = "flow.back"
    case flowGoTo = "flow.goTo"
    case submit
    case setFormValue
    case refresh
    case invoke
}
