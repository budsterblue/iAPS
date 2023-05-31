//
//  FilteredLoopsView.swift
//  FreeAPS
//
//  Created by Jon Mårtensson on 2023-05-29.
//
import Charts
import CoreData
import SwiftDate
import SwiftUI

struct ChartsView: View {
    @FetchRequest var fetchRequest: FetchedResults<Readings>

    @Binding var highLimit: Decimal
    @Binding var lowLimit: Decimal
    @Binding var units: GlucoseUnits
    @Binding var overrideUnit: Bool
    @Binding var standing: Bool

    @State var headline: Color = .secondary

    private let conversionFactor = 0.0555

    var body: some View {
        glucoseChart
        Rectangle().fill(.cyan.opacity(0.2)).frame(maxHeight: 3)
        if standing { tirChart } else { standingTIRchart }
    }

    init(
        filter: NSDate,
        _ highLimit: Binding<Decimal>,
        _ lowLimit: Binding<Decimal>,
        _ units: Binding<GlucoseUnits>,
        _ overrideUnit: Binding<Bool>,
        _ standing: Binding<Bool>
    ) { _fetchRequest = FetchRequest<Readings>(
        sortDescriptors: [NSSortDescriptor(key: "date", ascending: false)],
        predicate: NSPredicate(format: "glucose > 0 AND date > %@", filter)
    )
    _highLimit = highLimit
    _lowLimit = lowLimit
    _units = units
    _overrideUnit = overrideUnit
    _standing = standing
    }

    var glucoseChart: some View {
        // Be aware of the low/lowLimit difference. lowLimit/highLimit is always in mg/dl, whereas low/high is configurable in settings
        let low = lowLimit * (units == .mmolL ? Decimal(conversionFactor) : 1)
        let high = highLimit * (units == .mmolL ? Decimal(conversionFactor) : 1)
        let readings = fetchRequest
        let count = readings.count
        // The symbol size when fewer readings are larger
        let sizeOfDataPoints: CGFloat = count < 20 ? 50 : count < 50 ? 35 : count > 2000 ? 5 : 15

        return Chart {
            ForEach(readings.filter({ $0.glucose > Int(highLimit) }), id: \.date) { item in
                PointMark(
                    x: .value("Date", item.date ?? Date()),
                    y: .value("High", Double(item.glucose) * (units == .mmolL ? self.conversionFactor : 1))
                )
                .foregroundStyle(.orange)
                .symbolSize(sizeOfDataPoints)
            }
            ForEach(
                readings
                    .filter({
                        $0.glucose >= Int(lowLimit) && $0
                            .glucose <= Int(highLimit) }),
                id: \.date
            ) { item in
                PointMark(
                    x: .value("Date", item.date ?? Date()),
                    y: .value("In Range", Double(item.glucose) * (units == .mmolL ? conversionFactor : 1))
                )
                .foregroundStyle(.green)
                .symbolSize(sizeOfDataPoints)
            }
            ForEach(readings.filter({ $0.glucose < Int(lowLimit) }), id: \.date) { item in
                PointMark(
                    x: .value("Date", item.date ?? Date()),
                    y: .value("Low", Double(item.glucose) * (units == .mmolL ? conversionFactor : 1))
                )
                .foregroundStyle(.red)
                .symbolSize(sizeOfDataPoints)
            }
        }
        .chartYAxis {
            AxisMarks(
                values: [
                    0,
                    low,
                    high,
                    units == .mmolL ? 15 : 270
                ]
            )
        } // .background(.gray.opacity(0.05))
    }

    var tirChart: some View {
        let fetched = tir()

        let low = lowLimit * (units == .mmolL ? Decimal(conversionFactor) : 1)
        let high = highLimit * (units == .mmolL ? Decimal(conversionFactor) : 1)

        let data: [ShapeModel] = [
            .init(
                type: NSLocalizedString(
                    "Low",
                    comment: ""
                ) + " (\(low.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))))",
                percent: fetched[0].decimal
            ),
            .init(type: NSLocalizedString("In Range", comment: ""), percent: fetched[1].decimal),
            .init(
                type: NSLocalizedString(
                    "High",
                    comment: ""
                ) + " (\(high.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))))",
                percent: fetched[2].decimal
            )
        ]
        return Chart(data) { shape in
            BarMark(
                x: .value("TIR", shape.percent)
            )
            .foregroundStyle(by: .value("Group", shape.type))
            .annotation(position: .top, alignment: .center) {
                Text(
                    "\(shape.percent, format: .number.precision(.fractionLength(0))) %"
                ).font(.footnote).foregroundColor(.secondary)
            }
        }
        .chartXAxis(.hidden)
        .chartForegroundStyleScale([
            NSLocalizedString(
                "Low",
                comment: ""
            ) + " (\(low.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))))": .red,
            NSLocalizedString("In Range", comment: ""): .green,
            NSLocalizedString(
                "High",
                comment: ""
            ) + " (\(high.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))))": .orange
        ]).frame(maxHeight: 25)
    }

    var standingTIRchart: some View {
        let fetched = tir()
        let low = lowLimit * (units == .mmolL ? Decimal(conversionFactor) : 1)
        let high = highLimit * (units == .mmolL ? Decimal(conversionFactor) : 1)
        let data: [ShapeModel] = [
            .init(
                type: NSLocalizedString(
                    "Low",
                    comment: ""
                ) + " (\(low.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))))",
                percent: fetched[0].decimal
            ),
            .init(type: NSLocalizedString("In Range", comment: ""), percent: fetched[1].decimal),
            .init(
                type: NSLocalizedString(
                    "High",
                    comment: ""
                ) + " (\(high.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))))",
                percent: fetched[2].decimal
            )
        ]

        return VStack(alignment: .center) {
            Chart(data) { shape in
                BarMark(
                    x: .value("Shape", shape.type),
                    y: .value("Percentage", shape.percent)
                )
                .foregroundStyle(by: .value("Group", shape.type))
                .annotation(position: shape.percent <= 9 ? .top : .overlay, alignment: .center) {
                    Text(shape.percent == 0 ? "" : "\(shape.percent, format: .number.precision(.fractionLength(0))) %")
                }
            }
            .chartYAxis(.hidden)
            .chartLegend(.hidden)
            .chartForegroundStyleScale([
                NSLocalizedString(
                    "Low",
                    comment: ""
                ) + " (\(low.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))))": .red,
                NSLocalizedString("In Range", comment: ""): .green,
                NSLocalizedString(
                    "High",
                    comment: ""
                ) + " (\(high.formatted(.number.grouping(.never).rounded().precision(.fractionLength(1)))))": .orange
            ])
        }
    }

    private func tir() -> [(decimal: Decimal, string: String)] {
        let hypoLimit = Int(lowLimit)
        let hyperLimit = Int(highLimit)

        let glucose = fetchRequest

        let justGlucoseArray = glucose.compactMap({ each in Int(each.glucose as Int16) })
        let totalReadings = justGlucoseArray.count

        let hyperArray = glucose.filter({ $0.glucose >= hyperLimit })
        let hyperReadings = hyperArray.compactMap({ each in each.glucose as Int16 }).count
        let hyperPercentage = Double(hyperReadings) / Double(totalReadings) * 100

        let hypoArray = glucose.filter({ $0.glucose <= hypoLimit })
        let hypoReadings = hypoArray.compactMap({ each in each.glucose as Int16 }).count
        let hypoPercentage = Double(hypoReadings) / Double(totalReadings) * 100

        let tir = 100 - (hypoPercentage + hyperPercentage)

        var array: [(decimal: Decimal, string: String)] = []
        array.append((decimal: Decimal(hypoPercentage), string: "Low"))
        array.append((decimal: Decimal(tir), string: "NormaL"))
        array.append((decimal: Decimal(hyperPercentage), string: "High"))

        return array
    }
}