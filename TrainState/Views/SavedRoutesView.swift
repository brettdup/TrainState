import SwiftData
import SwiftUI
import CoreLocation

struct SavedRoutesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutRoute.updatedAt, order: .reverse) private var routes: [WorkoutRoute]
    @State private var showingCreateRoute = false
    @State private var editingRoute: WorkoutRoute?
    @State private var routeToDelete: WorkoutRoute?
    @State private var showingDeleteConfirmation = false

    private var savedRoutes: [WorkoutRoute] {
        routes.filter { $0.workout == nil && !($0.name?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true) }
    }

    var body: some View {
        NavigationStack {
            List {
                if savedRoutes.isEmpty {
                    ContentUnavailableView(
                        "No Saved Routes",
                        systemImage: "map",
                        description: Text("Create reusable running and cycling routes from the map.")
                    )
                } else {
                    ForEach(savedRoutes) { route in
                        Button {
                            editingRoute = route
                        } label: {
                            routeRow(route)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                routeToDelete = route
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Routes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateRoute = true
                    } label: {
                        Label("New Route", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateRoute) {
                SavedRouteEditorSheet(route: nil)
            }
            .sheet(item: $editingRoute) { route in
                SavedRouteEditorSheet(route: route)
            }
            .confirmationDialog("Delete Route", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteSelectedRoute()
                }
                Button("Cancel", role: .cancel) {
                    routeToDelete = nil
                }
            } message: {
                Text("This saved route will be permanently deleted.")
            }
        }
    }

    private func routeRow(_ route: WorkoutRoute) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(route.name ?? "Untitled Route")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            if let locations = route.decodedRoute, locations.count > 1 {
                RouteMapView(route: locations)
                    .frame(height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack {
                    Label("\(String(format: "%.2f", locations.routeDistanceKilometers)) km", systemImage: "ruler")
                    Spacer()
                    Text("Updated \(route.updatedAt.formatted(date: .abbreviated, time: .omitted))")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            } else {
                Text("No route points saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func deleteSelectedRoute() {
        guard let routeToDelete else { return }
        modelContext.delete(routeToDelete)
        try? modelContext.save()
        self.routeToDelete = nil
    }
}

struct SavedRoutePickerView: View {
    @Environment(\.dismiss) private var dismiss
    let routes: [WorkoutRoute]
    let tintColor: Color
    let onSelect: (WorkoutRoute) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(routes) { route in
                    Button {
                        onSelect(route)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(route.name ?? "Untitled Route")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)

                            if let locations = route.decodedRoute {
                                HStack {
                                    Label("\(String(format: "%.2f", locations.routeDistanceKilometers)) km", systemImage: "ruler")
                                    Text("\(locations.count) points")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Choose Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .tint(tintColor)
        }
    }
}

private struct SavedRouteEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    let route: WorkoutRoute?

    @State private var name: String
    @State private var draftRoute: [CLLocation]
    @State private var draftWaypoints: [CLLocation]
    @State private var waypointHistory: [[CLLocation]] = []
    @State private var showingFullScreenRoutePlanner = false

    init(route: WorkoutRoute?) {
        self.route = route
        _name = State(initialValue: route?.name ?? "New Route")
        _draftRoute = State(initialValue: route?.decodedRoute ?? [])
        _draftWaypoints = State(initialValue: route?.decodedWaypoints ?? route?.decodedRoute ?? [])
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Route Name") {
                    TextField("Route name", text: $name)
                }

                Section {
                    Button {
                        showingFullScreenRoutePlanner = true
                    } label: {
                        Label(draftWaypoints.isEmpty ? "Create Route on Map" : "Edit Route on Map", systemImage: "map")
                    }

                    HStack {
                        Label("\(String(format: "%.2f", draftRoute.routeDistanceKilometers)) km", systemImage: "ruler")
                        Spacer()
                        Text("\(draftWaypoints.count) points")
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.semibold))

                    HStack {
                        Button {
                            undoLastPoint()
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(!canUndo)

                        Spacer()

                        Button(role: .destructive) {
                            storeUndoState(draftWaypoints)
                            draftRoute.removeAll()
                            draftWaypoints.removeAll()
                        } label: {
                            Label("Clear", systemImage: "trash")
                        }
                        .disabled(draftWaypoints.isEmpty)
                    }
                    .buttonStyle(.borderless)

                    if draftRoute.count > 1 {
                        RouteMapView(route: draftRoute)
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .allowsHitTesting(false)
                    }
                } header: {
                    Text("Map")
                } footer: {
                    Text("Open the full-screen map to add points, press and drag markers, undo the last edit, or clear the full route. Add at least a start and finish point.")
                }
            }
            .navigationTitle(route == nil ? "New Route" : "Edit Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRoute()
                    }
                    .disabled(!canSave)
                }
            }
            .fullScreenCover(isPresented: $showingFullScreenRoutePlanner) {
                RoutePlannerSheetView(
                    route: draftRoute,
                    waypoints: draftWaypoints,
                    tintColor: .blue
                ) { route, waypoints in
                    storeUndoState(draftWaypoints)
                    draftRoute = route
                    draftWaypoints = waypoints
                }
            }
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && routeIsReady
    }

    private var routeIsReady: Bool {
        guard draftWaypoints.count > 1,
              draftRoute.count > 1,
              let firstWaypoint = draftWaypoints.first,
              let lastWaypoint = draftWaypoints.last,
              let firstRoutePoint = draftRoute.first,
              let lastRoutePoint = draftRoute.last else {
            return false
        }

        return firstRoutePoint.distance(from: firstWaypoint) < 50
            && lastRoutePoint.distance(from: lastWaypoint) < 50
    }

    private func undoLastPoint() {
        if let previousWaypoints = waypointHistory.popLast() {
            draftWaypoints = previousWaypoints
            draftRoute.removeAll()
        } else if !draftWaypoints.isEmpty {
            draftWaypoints.removeLast()
            draftRoute.removeAll()
        }
    }

    private var canUndo: Bool {
        !waypointHistory.isEmpty || !draftWaypoints.isEmpty
    }

    private func storeUndoState(_ waypoints: [CLLocation]) {
        guard !waypoints.isEmpty else { return }
        waypointHistory.append(waypoints)
    }

    private func saveRoute() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, draftRoute.count > 1, draftWaypoints.count > 1 else { return }

        let routeToSave = route ?? WorkoutRoute()
        routeToSave.name = trimmedName
        routeToSave.decodedRoute = draftRoute
        routeToSave.decodedWaypoints = draftWaypoints
        routeToSave.updatedAt = Date()

        if route == nil {
            routeToSave.createdAt = Date()
            modelContext.insert(routeToSave)
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    SavedRoutesView()
        .modelContainer(for: [WorkoutRoute.self, Workout.self], inMemory: true)
}
