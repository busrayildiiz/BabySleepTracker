# 💤 BabySleepTracker

A SwiftUI-based baby sleep tracking application built using MVVM architecture and clean separation of concerns.

## 📱 Overview

BabySleepTracker is a lightweight sleep logging application designed to track day naps and night sleep sessions. The app focuses on state-driven UI patterns, modular architecture, and maintainable code structure.

This project was built to practice scalable SwiftUI architecture and clean MVVM implementation.

---

## 🏗 Architecture

The application is structured using **MVVM (Model–View–ViewModel)** architecture.

### Folder Structure
BabySleepTracker
├── Models
├── ViewModels
├── Views
├── Services
├── Utils


### Key Architectural Decisions

- State-driven UI using `ObservableObject`
- Separation of business logic from Views
- Dedicated persistence layer (SleepStore)
- Codable-based local data storage
- Modular and scalable project structure

---

## ✨ Features

- Add day nap and night sleep sessions
- Group sleep records by day
- Display daily total sleep duration
- Local persistence using UserDefaults
- Clean, modular MVVM structure

---

## 🛠 Technologies Used

- Swift
- SwiftUI
- MVVM Architecture
- ObservableObject & State Management
- Codable
- UserDefaults (Local Persistence)

---

## 🚀 Future Improvements

- Data visualization (weekly sleep charts)
- SwiftData / CoreData persistence upgrade
- Sleep recommendation logic engine
- Cloud sync support
- Unit testing for ViewModels

---

## 👩🏻‍💻 Author

**Büşra Kalay**  
iOS Developer | Swift & SwiftUI | MVVM | Clean Architecture  

LinkedIn: https://linkedin.com/in/busrakalay  
GitHub: https://github.com/busrayildiiz

---

## 📌 Note

This project is actively evolving as part of ongoing iOS architecture and clean code practice.
