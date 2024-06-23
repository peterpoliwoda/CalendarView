//
//  CalendarView.swift
//
//
//  Created by Edon Valdman on 6/22/24.
//

import SwiftUI

/// A view that displays a calendar with date-specific decorations, and provides for user selection of a single date or multiple dates.
///
/// Configure the Calendar, Locale, and TimeZone by setting those values in the `Environment` (you can use the provided convenience View modifiers).
///
/// See [`UICalendarView`](https://developer.apple.com/documentation/uikit/uicalendarview) for more info.
///
/// > Important: When updating the `selection` Binding outside of `CalendarView`, be wary. If you create a `DateComponents` instance with components that aren't exactly the same as those set internally by `CalendarView`, you might get unexpected behavior, such as duplicate selections and more.
public struct CalendarView: UIViewRepresentable {
    /// The date components that represent the visible date in the calendar view.
    ///
    /// This essentially describes the visible view of the calendar.
    ///
    /// If `visibleDateComponents.calendar` is `nil` or isn't equal to [`calendar`](https://developer.apple.com/documentation/swiftui/environmentvalues/calendar), the view uses [`calendar`](https://developer.apple.com/documentation/swiftui/environmentvalues/calendar), which may result in an invalid date from the date components.
    public let visibleDateComponents: DateComponents?
    
    /// The range of dates that the calendar view displays.
    ///
    /// Set `availableDateRange` to restrict the earliest or latest dates that the calendar view displays. The default date range starts with [`distantPast`](https://developer.apple.com/documentation/foundation/date/1779829-distantpast) and ends with [`distantFuture`](https://developer.apple.com/documentation/foundation/date/1779684-distantfuture).
    public let availableDateRange: DateInterval?
    
    @Binding
    internal var selection: [DateComponents]
    internal let selectionMode: SelectionMode?
    
    /// Creates a calendar view with ordered, multiple selection.
    /// - Parameters:
    ///   - selection: A binding to an array that identifies selected dates.
    ///   - visibleDateComponents: The date components that represent the visible date in the calendar view. This essentially describes the visible view of the calendar. Leave `nil` for default value, which is the current month.
    ///   - availableDateRange: The range of dates that the calendar view displays and allows for selection. Leave `nil` for no limit.
    public init(
        _ selection: Binding<[DateComponents]>,
        visibleDateComponents: DateComponents? = nil,
        availableDateRange: DateInterval? = nil
    ) {
        self._selection = selection
        self.selectionMode = .multiDate
        self.visibleDateComponents = visibleDateComponents
        self.availableDateRange = availableDateRange
    }
    
    /// Creates a calendar view with unordered, multiple selection.
    /// - Parameters:
    ///   - selection: A binding to an unordered set that identifies selected dates.
    ///   - visibleDateComponents: The date components that represent the visible date in the calendar view. This essentially describes the visible view of the calendar. Leave `nil` for default value, which is the current month.
    ///   - availableDateRange: The range of dates that the calendar view displays and allows for selection. Leave `nil` for no limit.
    public init(
        _ selection: Binding<Set<DateComponents>>,
        visibleDateComponents: DateComponents? = nil,
        availableDateRange: DateInterval? = nil
    ) {
        self.init(
            selection.map { set in
                Array(set)
            } reverse: { arr in
                Set(arr)
            },
            visibleDateComponents: visibleDateComponents,
            availableDateRange: availableDateRange
        )
    }
    
    /// Creates a calendar view, optionally with single selection.
    /// - Parameters:
    ///   - selection: A binding to a selected date.
    ///   - visibleDateComponents: The date components that represent the visible date in the calendar view. This essentially describes the visible view of the calendar. Leave `nil` for default value, which is the current month.
    ///   - availableDateRange: The range of dates that the calendar view displays and allows for selection. Leave `nil` for no limit.
    public init(
        _ selection: Binding<DateComponents?>? = nil,
        visibleDateComponents: DateComponents? = nil,
        availableDateRange: DateInterval? = nil
    ) {
        if let selection {
            self._selection = selection.map { value in
                [value].compactMap { $0 }
            } reverse: { arr in
                arr.first
            }
            self.selectionMode = .singleDate
        } else {
            self._selection = .constant([])
            self.selectionMode = nil
        }
        self.visibleDateComponents = visibleDateComponents
        self.availableDateRange = availableDateRange
    }
    
    public func makeUIView(context: Context) -> UICalendarView {
        let view = UICalendarView(frame: .zero)
        
        if let selectionMode = self.selectionMode {
            switch selectionMode {
            case .singleDate:
                view.selectionBehavior = UICalendarSelectionSingleDate(delegate: context.coordinator)
            case .multiDate:
                view.selectionBehavior = UICalendarSelectionMultiDate(delegate: context.coordinator)
            default:
                view.selectionBehavior = nil
            }
        } else {
            view.selectionBehavior = nil
        }
        
        if let visibleDateComponents {
            view.visibleDateComponents = visibleDateComponents
        }
        
        if let availableDateRange {
            view.availableDateRange = availableDateRange
        }
        
        view.fontDesign = self.fontDesign
        view.wantsDateDecorations = self.decorationCallback != nil
        view.delegate = self.decorationCallback != nil ? context.coordinator : nil
        
        return view
    }
    
    public func updateUIView(_ uiView: UICalendarView, context: Context) {
        uiView.calendar = context.environment.calendar
        uiView.locale = context.environment.locale
        uiView.timeZone = context.environment.timeZone
        
        if let selectionObj = uiView.selectionBehavior {
            if self.selectionMode == .singleDate,
               let singleDate = selectionObj as? UICalendarSelectionSingleDate,
               singleDate.selectedDate != self.selection.first {
                singleDate.setSelected(
                    self.selection.first,
                    animated: context.transaction.animation != nil
                )
            } else if self.selectionMode == .multiDate,
                      let multiDate = selectionObj as? UICalendarSelectionMultiDate,
                      multiDate.selectedDates != self.selection {
                multiDate.setSelectedDates(
                    self.selection,
                    animated: context.transaction.animation != nil
                )
            }
        }
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Misc Modifier Properties
    
    private var fontDesign: UIFontDescriptor.SystemDesign = .default
    
    /// A font design that the calendar view uses for displaying calendar text.
    ///
    /// Defaults to [`default`](https://developer.apple.com/documentation/uikit/uifontdescriptor/systemdesign/3151799-default).
    public func fontDesign(_ design: UIFontDescriptor.SystemDesign) -> CalendarView {
        var new = self
        new.fontDesign = design
        return new
    }
    
    public typealias DecorationCallback = (_ dateComponents: DateComponents) -> Decoration?
    internal var decorationCallback: DecorationCallback? = nil
    internal var dateSpecificDecorations: [DateComponents: Decoration] = [:]
    
    /// Set decoration views for dates in the CalendarView.
    public func decorations(_ callback: DecorationCallback? = nil) -> CalendarView {
        var new = self
        new.decorationCallback = callback
        return new
    }
    
    /// Set decoration views for specific dates in the CalendarView.
    public func decorations<C>(
        for dates: C,
        _ decoration: Decoration?
    ) -> CalendarView where C: Collection, C.Element == DateComponents {
        var new = self
        if let decoration {
            new.dateSpecificDecorations.merge(
                dates.reduce(into: [:]) { $0[$1] = decoration },
                uniquingKeysWith: { (_, new) in new }
            )
        } else {
            for key in dates {
                new.dateSpecificDecorations.removeValue(forKey: key)
            }
        }
        return new
    }
    
    /// Set decoration views for a specific date in the CalendarView.
    public func decorations(for date: DateComponents, _ decoration: Decoration?) -> CalendarView {
        self.decorations(for: CollectionOfOne(date), decoration)
    }
}
