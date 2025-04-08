//
//  ContentView.swift
//  otoparkTakip
//
//  Created by Mustafa Tümsek on 8.04.2025.
//

import SwiftUI

struct Vehicle: Identifiable, Codable {
    let id: UUID
    let plate: String
    let entryTime: Date
    
    // Custom initializer for decoding
    init(id: UUID = UUID(), plate: String, entryTime: Date) {
        self.id = id
        self.plate = plate
        self.entryTime = entryTime
    }
    
    // Conform to Codable by using CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case plate
        case entryTime
    }
}

class ParkingViewModel: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var pastVehicles: [PastVehicle] = []

    @Published var plateInput: String = ""
    @Published var firstHourRate: Double = 30.0
    @Published var extraHourRate: Double = 20.0

    private let vehiclesKey = "vehicles"
    private let pastVehiclesKey = "pastVehicles"

    init() {
        loadVehicles()
        loadPastVehicles()
    }

    func addVehicle() {
        let trimmedPlate = plateInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPlate.isEmpty else { return }

        let newVehicle = Vehicle(plate: trimmedPlate, entryTime: Date())
        vehicles.append(newVehicle)
        plateInput = ""
        saveVehicles()
    }

    func removeVehicle(_ vehicle: Vehicle) -> Double {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return 0 }

        let exitTime = Date()
        let duration = exitTime.timeIntervalSince(vehicle.entryTime)
        let fee = calculateFee(for: duration)

        // Geçmişe ekle
        let past = PastVehicle(plate: vehicle.plate, entryTime: vehicle.entryTime, exitTime: exitTime, fee: fee)
        pastVehicles.insert(past, at: 0)

        vehicles.remove(at: index)
        saveVehicles()
        savePastVehicles()

        return fee
    }

    private func calculateFee(for duration: TimeInterval) -> Double {
        let totalHours = duration / 3600
        if totalHours <= 1 {
            return firstHourRate
        } else {
            let extraHours = ceil(totalHours - 1)
            return firstHourRate + (extraHours * extraHourRate)
        }
    }

    func timeElapsedSinceEntry(_ vehicle: Vehicle) -> String {
        let interval = Date().timeIntervalSince(vehicle.entryTime)
        
        // Zaman farkını saat ve dakikaya dönüştürme
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        // Süreyi formatlayıp döndürme
        if hours > 0 {
            return "\(hours) sa \(minutes) dk"
        } else {
            return "\(minutes) dk"
        }
    }


    private func saveVehicles() {
        if let encoded = try? JSONEncoder().encode(vehicles) {
            UserDefaults.standard.set(encoded, forKey: vehiclesKey)
        }
    }

    private func savePastVehicles() {
        if let encoded = try? JSONEncoder().encode(pastVehicles) {
            UserDefaults.standard.set(encoded, forKey: pastVehiclesKey)
        }
    }

    private func loadVehicles() {
        if let data = UserDefaults.standard.data(forKey: vehiclesKey),
           let decoded = try? JSONDecoder().decode([Vehicle].self, from: data) {
            vehicles = decoded
        }
    }

    private func loadPastVehicles() {
        if let data = UserDefaults.standard.data(forKey: pastVehiclesKey),
           let decoded = try? JSONDecoder().decode([PastVehicle].self, from: data) {
            pastVehicles = decoded
        }
    }
}




struct SettingsView: View {     //ayarlar
    @Binding var firstHourRate: Double
    @Binding var extraHourRate: Double

    var body: some View {
        Form {
            Section(header: Text("Ücretlendirme")) {
                Stepper(value: $firstHourRate, in: 0...100, step: 5) {
                    Text("İlk Saat: ₺\(firstHourRate, specifier: "%.0f")")
                }

                Stepper(value: $extraHourRate, in: 0...100, step: 5) {
                    Text("Sonraki Saatler: ₺\(extraHourRate, specifier: "%.0f")")
                }
            }
        }
        .navigationTitle("Ayarlar")
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: ParkingViewModel

    var body: some View {
        List {
            if viewModel.pastVehicles.isEmpty {
                Text("Henüz geçmiş veri yok.")
                    .foregroundColor(.gray)
            } else {
                ForEach(viewModel.pastVehicles) { vehicle in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.plate)
                            .font(.headline)
                        Text("Giriş: \(vehicle.entryTime.formatted(date: .abbreviated, time: .shortened))")
                        Text("Çıkış: \(vehicle.exitTime.formatted(date: .abbreviated, time: .shortened))")
                        Text("Ücret: ₺\(vehicle.fee, specifier: "%.2f")")
                            .foregroundColor(.blue)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Geçmiş Araçlar")
    }
}


struct PastVehicle: Identifiable, Codable {
    let id: UUID
    let plate: String
    let entryTime: Date
    let exitTime: Date
    let fee: Double
    
    // Custom initializer for decoding
    init(id: UUID = UUID(), plate: String, entryTime: Date, exitTime: Date, fee: Double) {
        self.id = id
        self.plate = plate
        self.entryTime = entryTime
        self.exitTime = exitTime
        self.fee = fee
    }
    
    // Conform to Codable by using CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case plate
        case entryTime
        case exitTime
        case fee
    }
}


struct ParkingView: View {
    @StateObject private var viewModel = ParkingViewModel()
    @State private var showingFee: Bool = false
    @State private var lastFee: Double = 0.0

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                HStack {
                    
                    TextField("Plaka girin", text: $viewModel.plateInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.allCharacters)

                    Button("Ekle") {
                        viewModel.addVehicle()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)

                List {
                    ForEach(viewModel.vehicles) { vehicle in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(vehicle.plate)
                                    .font(.headline)
                                Text("Giriş: \(vehicle.entryTime.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(viewModel.timeElapsedSinceEntry(vehicle))")
                                    .font(.headline)
                            }
                            Spacer()
                            Button("Çıkış Yap") {
                                lastFee = viewModel.removeVehicle(vehicle)
                                showingFee = true
                            }
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                    }
                }

            }
            .padding(.top)
            .navigationTitle("Otopark Takip")
            .toolbar {
                HStack {
                    NavigationLink(destination:
                        SettingsView(firstHourRate: $viewModel.firstHourRate,
                                     extraHourRate: $viewModel.extraHourRate)) {
                        Image(systemName: "gearshape")
                    }

                    NavigationLink(destination:
                        HistoryView(viewModel: viewModel)) {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
            }


            .alert(isPresented: $showingFee) {
                Alert(title: Text("Ücret Hesaplandı"),
                      message: Text("Toplam ücret: ₺\(lastFee, specifier: "%.2f")"),
                      dismissButton: .default(Text("Tamam")))
            }
        }
    }
}

#Preview {
    ParkingView()
}






