# Road Trip Tracker

iOS-приложение для записи автопутешествий. GPS-трекинг маршрута, скорости, высоты и дистанции.

## Что умеет

- Запись маршрута с GPS (Kalman filter для сглаживания)
- Карта с отображением маршрута и направления движения
- Сворачиваемая панель показателей: скорость, высота, дистанция, время
- Компас
- История поездок с детальной статистикой
- Фоновая запись GPS
- Dev mode с виртуальным джойстиком для тестирования

## Стек

- Swift / SwiftUI, iOS 17+
- MapKit
- CoreData
- CoreLocation
- Без внешних зависимостей

## Структура

```
RoadTripTracker/
├── App/                    — точка входа
├── Models/                 — Trip, TrackPoint
├── Services/               — LocationService (GPS), TripManager (бизнес-логика)
├── Persistence/            — CoreData stack и схема
├── Views/
│   ├── Tracking/           — карта, HUD, спидометр
│   ├── Trips/              — список и детали поездок
│   ├── Regions/            — заглушка scratch map
│   └── Components/         — переиспользуемые компоненты, dev menu
├── ViewModels/             — TrackingViewModel, TripsViewModel
└── Resources/              — Assets
```

## Сборка

```bash
cp Local.xcconfig.example Local.xcconfig  # вписать свой bundle ID
brew install xcodegen
xcodegen generate
open RoadTripTracker.xcodeproj
```

Xcode → выбрать устройство → Cmd+R.

## Лицензия

MIT
