//
//  EventMapView.swift
//  Famoria 2026
//
//  MapKit-based location preview — translates the React `EventMapView`
//  (Nominatim geocoding + Leaflet) to native CoreLocation + MapKit.
//
//  • Geocodes the supplied free-form `location` string
//  • Renders an interactive Map with a marker
//  • Provides "Open in Apple Maps" / "Open in Google Maps" buttons
//

import SwiftUI
import MapKit
import CoreLocation

struct EventMapView: View {
    let location: String
    let eventTitle: String

    @State private var coordinate: CLLocationCoordinate2D?
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isLoading: Bool = false
    @State private var loadError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Event Location", systemImage: "mappin.and.ellipse")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.blue)
                Spacer()
                openMapsButtons
            }

            Text(location)
                .font(.footnote)
                .foregroundColor(.secondary)

            mapBody
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.25), lineWidth: 1)
        )
        .task(id: location) {
            await geocode()
        }
    }

    // MARK: - Map content

    @ViewBuilder
    private var mapBody: some View {
        if isLoading {
            ZStack {
                Color(.secondarySystemBackground)
                ProgressView("Loading map…").font(.caption)
            }
        } else if let coordinate {
            Map(initialPosition: .region(region), interactionModes: [.zoom, .pan]) {
                Annotation(eventTitle, coordinate: coordinate, anchor: .center) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }
        } else if loadError {
            ZStack {
                Color(.secondarySystemBackground)
                VStack(spacing: 6) {
                    Image(systemName: "mappin.slash").font(.title2).foregroundColor(.secondary)
                    Text("Location not found")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } else {
            Color(.secondarySystemBackground)
        }
    }

    // MARK: - Maps app links

    private var openMapsButtons: some View {
        HStack(spacing: 8) {
            Button {
                openInAppleMaps()
            } label: {
                Label("Apple Maps", systemImage: "arrow.up.right.square")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)

            Button {
                openInGoogleMaps()
            } label: {
                Label("Google", systemImage: "arrow.up.right.square")
                    .font(.caption2)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
        }
    }

    private func openInAppleMaps() {
        guard let q = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "http://maps.apple.com/?q=\(q)") else { return }
        UIApplication.shared.open(url)
    }

    private func openInGoogleMaps() {
        guard let q = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.google.com/maps/search/?api=1&query=\(q)") else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Geocoding

    private func geocode() async {
        guard !location.isEmpty else { return }
        isLoading = true
        loadError = false
        defer { isLoading = false }

        // Use MapKit's search-based geocoding to avoid deprecated CLGeocoder
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = location
        // Provide a region hint based on the current region to improve relevance
        request.region = region

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            if let firstItem = response.mapItems.first {
                let coord = firstItem.location.coordinate
                coordinate = coord
                region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            } else {
                loadError = true
            }
        } catch {
            loadError = true
        }
    }
}

// MARK: - Annotation helper

private struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

#Preview {
    EventMapView(location: "Apple Park, Cupertino, CA", eventTitle: "Family Reunion")
        .padding()
}
