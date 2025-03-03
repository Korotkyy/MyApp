import SwiftUI

// Структура для событий календаря
struct CalendarEvent: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var date: Date
    var notes: String
    var time: Date
    
    static func == (lhs: CalendarEvent, rhs: CalendarEvent) -> Bool {
        lhs.id == rhs.id  // Сравниваем только по id
    }
}

struct DayView: View {
    let date: Date
    @Binding var selectedEvents: [CalendarEvent]
    let saveEvents: () -> Void
    let deleteEvent: (CalendarEvent) -> Void
    @State private var showingEventSheet = false
    @State private var newEventTitle = ""
    @State private var newEventNotes = ""
    @State private var newEventTime = Date()
    @State private var isEditing = false
    @State private var editingEvent: CalendarEvent?
    @Environment(\.dismiss) var dismiss
    // Добавляем доступ к проектам
    let savedProjects: [SavedProject]
    
    var eventsForDay: [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return selectedEvents.filter { event in
            let eventDate = calendar.startOfDay(for: event.date)
            return eventDate == startOfDay
        }
        .sorted { $0.time < $1.time }
    }
    
    // Получаем проекты с дедлайном на этот день
    var projectsForDay: [SavedProject] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        return savedProjects.filter { project in
            if let deadline = project.deadline {
                return calendar.startOfDay(for: deadline) == startOfDay
            }
            return false
        }
    }
    
    private func deleteEvents(at offsets: IndexSet) {
        for index in offsets {
            let event = eventsForDay[index]
            deleteEvent(event)
        }
    }
    
    var body: some View {
        ZStack {
            Color.customDarkNavy.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Секция дедлайнов проектов
                    if !projectsForDay.isEmpty {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Project Deadlines")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                            
                            ForEach(projectsForDay) { project in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(project.projectName)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    ForEach(project.goals) { goal in
                                        VStack(alignment: .leading, spacing: 5) {
                                            HStack {
                                                Text(goal.text)
                                                    .foregroundColor(.white)
                                                Spacer()
                                                Text(goal.progress)
                                                    .foregroundColor(.customAccent)
                                            }
                                            
                                            // Прогресс-бар
                                            GeometryReader { geometry in
                                                let total = Double(Int(goal.totalNumber) ?? 0)
                                                let remaining = Double(Int(goal.remainingNumber) ?? 0)
                                                let progress = total > 0 ? (total - remaining) / total : 0
                                                
                                                ZStack(alignment: .leading) {
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(height: 4)
                                                    
                                                    Rectangle()
                                                        .fill(Color.customAccent)
                                                        .frame(width: geometry.size.width * progress, height: 4)
                                                }
                                            }
                                            .frame(height: 4)
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.customNavy)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        
                        Divider()
                            .background(Color.gray)
                            .padding(.vertical)
                    }
                    
                    // Секция событий
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Events")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                        
                        ForEach(eventsForDay) { event in
                            EventRow(
                                event: event,
                                onEdit: {
                                    editingEvent = event
                                    newEventTitle = event.title
                                    newEventNotes = event.notes
                                    newEventTime = event.time
                                    isEditing = true
                                    showingEventSheet = true
                                },
                                onDelete: deleteEvent
                            )
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            
            // Кнопка добавления события
            VStack {
                Spacer()
                Button {
                    editingEvent = nil
                    newEventTitle = ""
                    newEventNotes = ""
                    newEventTime = Date()
                    isEditing = false
                    showingEventSheet = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Event")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.customAccent)
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .navigationTitle(date.formatted(date: .complete, time: .omitted))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEventSheet) {
            NavigationView {
                Form {
                    TextField("Event Title", text: $newEventTitle)
                    DatePicker("Time", selection: $newEventTime, displayedComponents: [.hourAndMinute])
                    TextField("Notes", text: $newEventNotes)
                }
                .navigationTitle(isEditing ? "Edit Event" : "New Event")
                .navigationBarItems(
                    leading: Button("Cancel") {
                        showingEventSheet = false
                    },
                    trailing: Button(isEditing ? "Save" : "Add") {
                        if isEditing {
                            if let editingEvent = editingEvent,
                               let index = selectedEvents.firstIndex(where: { $0.id == editingEvent.id }) {
                                var updatedEvent = selectedEvents[index]
                                updatedEvent.title = newEventTitle
                                updatedEvent.notes = newEventNotes
                                updatedEvent.time = newEventTime
                                selectedEvents[index] = updatedEvent
                                saveEvents()
                            }
                        } else {
                            let newEvent = CalendarEvent(
                                id: UUID(),
                                title: newEventTitle,
                                date: date,
                                notes: newEventNotes,
                                time: newEventTime
                            )
                            selectedEvents.append(newEvent)
                            saveEvents()
                        }
                        showingEventSheet = false
                    }
                    .disabled(newEventTitle.isEmpty)
                )
            }
        }
    }
}

// Отдельное представление для строки события
struct EventRow: View {
    let event: CalendarEvent
    let onEdit: () -> Void
    let onDelete: (CalendarEvent) -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(event.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(event.time, style: .time)
                    .font(.subheadline)
                    .foregroundColor(.customAccent)
                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .padding(.vertical, 5)
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.customAccent)
                    .font(.title3)
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                onDelete(event)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct CalendarUnderlineModifier: ViewModifier {
    let hasEvents: (Date) -> Bool
    let getDateColor: (Date) -> Color
    let selectedDate: Date
    
    func body(content: Content) -> some View {
        content.overlay(
            GeometryReader { geometry in
                let calendar = Calendar.current
                let currentMonth = calendar.component(.month, from: selectedDate)
                let currentYear = calendar.component(.year, from: selectedDate)
                
                ForEach(1...31, id: \.self) { day in
                    if let date = calendar.date(from: DateComponents(year: currentYear, month: currentMonth, day: day)) {
                        if hasEvents(date) {
                            Rectangle()
                                .fill(getDateColor(date))
                                .frame(width: 25, height: 1)
                                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                        }
                    }
                }
            }
        )
    }
}

struct CustomCalendarView: View {
    @Binding var selectedDate: Date
    let hasEvents: (Date) -> Bool
    let getDateColor: (Date) -> Color
    let onDateSelected: () -> Void
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 1
        cal.locale = Locale(identifier: "en_US")
        return cal
    }
    
    private let daysOfWeek = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
    @State private var currentMonth: Date
    
    init(selectedDate: Binding<Date>, hasEvents: @escaping (Date) -> Bool, getDateColor: @escaping (Date) -> Color, onDateSelected: @escaping () -> Void) {
        self._selectedDate = selectedDate
        self.hasEvents = hasEvents
        self.getDateColor = getDateColor
        self.onDateSelected = onDateSelected
        self._currentMonth = State(initialValue: selectedDate.wrappedValue)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Заголовок месяца и кнопки навигации
            HStack {
                Button(action: previousMonth) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Text(currentMonth.formatted(.dateTime.year().month()))
                    .font(.title3)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: nextMonth) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            
            // Дни недели
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.gray)
                }
            }
            
            // Дни месяца
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 10) {
                ForEach(getDaysInMonth(), id: \.self) { date in
                    if let date = date {
                        DayCell(
                            date: date,
                            isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                            isCurrentMonth: calendar.isDate(date, equalTo: currentMonth, toGranularity: .month),
                            hasEvent: hasEvents(date)
                        )
                        .onTapGesture {
                            selectedDate = date
                            onDateSelected()
                        }
                    } else {
                        Color.clear
                            .frame(height: 35)
                    }
                }
            }
        }
        .padding()
        .background(Color.customNavy)
        .cornerRadius(12)
    }
    
    private func getDaysInMonth() -> [Date?] {
        let interval = calendar.dateInterval(of: .month, for: currentMonth)!
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        
        // Добавим отладочную печать
        print("First weekday of month: \(firstWeekday)")
        print("Calendar first weekday: \(calendar.firstWeekday)")
        
        let offsetDays = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        let daysInMonth = calendar.range(of: .day, in: .month, for: currentMonth)!.count
        
        var days: [Date?] = Array(repeating: nil, count: offsetDays)
        
        for day in 1...daysInMonth {
            if let date = calendar.date(from: DateComponents(year: calendar.component(.year, from: currentMonth),
                                                           month: calendar.component(.month, from: currentMonth),
                                                           day: day)) {
                days.append(date)
            }
        }
        
        while days.count < 42 {
            days.append(nil)
        }
        
        return days
    }
    
    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = newDate
        }
    }
    
    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = newDate
        }
    }
}

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isCurrentMonth: Bool
    let hasEvent: Bool
    
    var body: some View {
        ZStack {
            if isSelected {
                Circle()
                    .fill(Color.customAccent)
                    .frame(width: 40, height: 40)
            }
            
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 17))
                .foregroundColor(
                    isSelected ? .black :
                        isCurrentMonth ? (hasEvent ? Color.customAccent : .white) : .gray
                )
        }
        .frame(width: 40, height: 40)
    }
}

struct CalendarView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedDate = Date()
    @State private var showingSecondView = false
    @State private var selectedEvents: [CalendarEvent] = []
    @AppStorage("calendarEvents") private var eventsData: Data = Data()
    @State private var showDayView = false
    @State private var currentProjectId: UUID?
    
    @Binding var savedProjects: [SavedProject]
    @Binding var selectedImage: Image?
    @Binding var goals: [Goal]
    @Binding var cells: [Cell]
    @Binding var showGrid: Bool
    
    private func loadEvents() {
        if let decoded = try? JSONDecoder().decode([CalendarEvent].self, from: eventsData) {
            selectedEvents = decoded
        }
    }
    
    private func saveEvents() {
        if let encoded = try? JSONEncoder().encode(selectedEvents) {
            eventsData = encoded
        }
    }
    
    var eventsForSelectedDate: [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return selectedEvents.filter { event in
            let eventDate = calendar.startOfDay(for: event.date)
            return eventDate == startOfDay
        }
        .sorted { $0.time < $1.time }
    }
    
    private func deleteEvent(_ event: CalendarEvent) {
        withAnimation {
            selectedEvents.removeAll { $0.id == event.id }
            saveEvents()
            
            // Если после удаления в текущем дне нет событий, закрываем DayView
            if eventsForSelectedDate.isEmpty {
                showDayView = false
            }
        }
    }
    
    private func hasEvents(for date: Date) -> Bool {
        let calendar = Calendar.current
        let dateToCheck = calendar.startOfDay(for: date)
        
        // Проверяем события
        let hasCalendarEvents = selectedEvents.contains { event in
            calendar.startOfDay(for: event.date) == dateToCheck
        }
        
        // Проверяем дедлайны проектов
        let hasDeadlines = savedProjects.contains { project in
            if let deadline = project.deadline {
                return calendar.startOfDay(for: deadline) == dateToCheck
            }
            return false
        }
        
        return hasCalendarEvents || hasDeadlines
    }
    
    // Получаем цвет для даты (зеленый для дедлайнов, accent для обычных событий)
    private func getDateColor(_ date: Date) -> Color {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        
        // Проверяем дедлайны
        let hasDeadline = savedProjects.contains { project in
            if let deadline = project.deadline {
                return calendar.startOfDay(for: deadline) == startOfDay
            }
            return false
        }
        
        return hasDeadline ? .green : .customAccent
    }
    
    // Функция для форматирования оставшихся дней
    private func formatRemainingDays(deadline: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        guard let days = components.day else { return "" }
        
        if days < 0 {
            return "Overdue"
        } else if days == 0 {
            return "Due today"
        } else if days == 1 {
            return "1 day left"
        } else {
            return "\(days) days left"
        }
    }
    
    // Функция для определения цвета статуса дедлайна
    private func deadlineStatusColor(deadline: Date) -> Color {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: deadline)
        guard let days = components.day else { return .white }
        
        if days < 0 {
            return .red
        } else if days <= 3 {
            return .orange
        } else {
            return .green
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.customDarkNavy.ignoresSafeArea()
                
                VStack {
                    CustomCalendarView(
                        selectedDate: $selectedDate,
                        hasEvents: hasEvents,
                        getDateColor: getDateColor,
                        onDateSelected: {
                            showDayView = true
                        }
                    )
                    .padding()
                    
                    // Показываем список дедлайнов на выбранную дату
                    if let deadlines = getDeadlinesForSelectedDate() {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Deadlines:")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ForEach(deadlines, id: \.id) { project in
                                if let deadline = project.deadline {
                                    HStack {
                                        Text(project.projectName)
                                            .foregroundColor(.white)
                                            .font(.system(size: 17, weight: .medium))
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        Text(formatRemainingDays(deadline: deadline))
                                            .foregroundColor(deadlineStatusColor(deadline: deadline))
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .padding(.vertical, 5)
                                }
                            }
                        }
                        .padding()
                        .background(Color.customNavy)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            // Остаемся на текущей странице
                        }) {
                            Label("Calendar", systemImage: "calendar")
                                .foregroundColor(.gray)
                        }
                        .disabled(true)
                        
                        Button(action: {
                            showingSecondView = true
                        }) {
                            Label("My Goals", systemImage: "list.bullet")
                        }
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Label("Main", systemImage: "house")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Text("Calendar")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .background(
                NavigationLink(isActive: $showDayView) {
                    DayView(
                        date: selectedDate,
                        selectedEvents: $selectedEvents,
                        saveEvents: saveEvents,
                        deleteEvent: deleteEvent,
                        savedProjects: savedProjects
                    )
                } label: {
                    EmptyView()
                }
            )
        }
        .sheet(isPresented: $showingSecondView) {
            SecondView(
                savedProjects: $savedProjects,
                selectedImage: $selectedImage,
                goals: $goals,
                isPresented: $showingSecondView,
                cells: $cells,
                showGrid: $showGrid,
                currentProjectId: $currentProjectId,
                projectName: .constant(""),
                originalUIImage: .constant(nil),
                selectedDeadline: .constant(nil)
            )
        }
        .onChange(of: selectedEvents) { _ in
            saveEvents()
        }
        .onAppear {
            loadEvents()
        }
    }
    
    // Функция для получения проектов с дедлайном на выбранную дату
    private func getDeadlinesForSelectedDate() -> [SavedProject]? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        
        let projectsWithDeadline = savedProjects.filter { project in
            if let deadline = project.deadline {
                return calendar.startOfDay(for: deadline) == startOfDay
            }
            return false
        }
        
        return projectsWithDeadline.isEmpty ? nil : projectsWithDeadline
    }
}
