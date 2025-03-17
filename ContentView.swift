import SwiftUI
import Foundation 

struct ContentView: View {
    @State private var schedulePressed = false
    
    // Screen that is presented once user presses Schedule
    var body: some View {
        NavigationView {
            VStack {
                // Three options of what to do/press
                Spacer()
                NavigationLink("Add Task", destination: AddTaskView(isPresented: $schedulePressed))
                    .shadow(color: .gray, radius: 2, x: 1, y: 1)
                Spacer()
                NavigationLink("Schedule", destination: ScheduleView(isPresented: $schedulePressed))
                    .shadow(color: .gray, radius: 2, x: 1, y: 1)
                Spacer()
                NavigationLink("View All Tasks", destination: AllView())
                    .shadow(color: .gray, radius: 2, x: 1, y: 1)
                Spacer()
            }
            .navigationBarTitle("Prioritize Yourself")
            .font(.system(size: 30, weight: .bold, design: .default))
            .foregroundColor(.teal)
        }
    }
}

struct AddTaskView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var viewModel = ScheduleViewModel.shared
    
    // Button to enter task once fields are filled out
    @State private var enterPressed = false
    
    // Fields user has to enter
    @State private var taskName = ""
    @State private var selectedDifficulty = 0
    let difficultyOptions = ["Easy", "Moderate", "Difficult"]
    @State private var dueDate = Date()
    
    @State private var schedulePresented = false 
    
    var body: some View {
        NavigationView{
            VStack {
                // Task Name
                TextField("Task Name", text: $taskName)
                    .padding()
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                    .foregroundColor(.white)
                
                // Difficulty Picker
                Picker("Select Difficulty", selection: $selectedDifficulty) {
                    ForEach(difficultyOptions.indices, id: \.self) { index in
                        Text(difficultyOptions[index])
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Due Date Picker
                DatePicker("Due Date", selection: $dueDate, in: Date()..., displayedComponents: .date)
                    .padding(.horizontal)
                
                // Enter Button
                Button(action: {
                    viewModel.addTask(taskName, dueDate: dueDate, difficulty: difficultyOptions[selectedDifficulty])
                    isPresented.toggle()
                }) {
                    Text("Enter")
                        .font(.system(size: 25))
                        .padding()
                        .foregroundColor(.indigo)
                        .background(Color.teal)
                        .cornerRadius(15)
                        .shadow(color: .gray, radius: 2, x: 1, y: 1)
                }
                .padding()
                .background(Color.black)
            }
            .navigationTitle("Add Task")
            .fullScreenCover(isPresented: $isPresented) {
                ContentView()
            }
            .background(Color.black)
        }
         .navigationViewStyle(StackNavigationViewStyle()) 
    } 
}

// Class to identify each task for organization
class ScheduleViewModel: ObservableObject {
    static let shared = ScheduleViewModel()
    
    struct Task: Identifiable {
        let id = UUID()
        let name: String
        let dueDate: Date
        let difficulty: String
        var isCompleted: Bool = false
    }
    
    @Published var completedTasks: [Task] = []
    @Published var tasksByDate = [String: [Task]]()
    
    func addTask(_ taskName: String, dueDate: Date, difficulty: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        
        // If task is easy, then it should be presented only one day before the due date
        let easyDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) ?? dueDate
        // If task is moderate, then it should be presented both days before the due date
        let moderateDate = Calendar.current.date(byAdding: .day, value: -2, to: dueDate) ?? dueDate
        // If task is difficult, then it should be presented the three days before the due date
        let difficultDate = Calendar.current.date(byAdding: .day, value: -3, to: dueDate) ?? dueDate
        
        switch difficulty {
        case "Easy":
            addTaskToDictionary(taskName, dueDate: dueDate, date: easyDate, difficulty: "Easy")
        case "Moderate":
            addTaskToDictionary(taskName, dueDate: dueDate, date: moderateDate, difficulty: "Moderate")
            addTaskToDictionary(taskName, dueDate: dueDate, date: easyDate, difficulty: "Easy")
        case "Difficult":
            addTaskToDictionary(taskName, dueDate: dueDate, date: difficultDate, difficulty: "Difficult")
            addTaskToDictionary(taskName, dueDate: dueDate, date: moderateDate, difficulty: "Moderate")
            addTaskToDictionary(taskName, dueDate: dueDate, date: easyDate, difficulty: "Easy")
        default:
            break
        }
    }
    
    // Adds task to array with all fields filled in
    private func addTaskToDictionary(_ taskName: String, dueDate: Date, date: Date, difficulty: String) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        let dateString = dateFormatter.string(from: date)
        let task = ScheduleViewModel.Task(name: taskName, dueDate: dueDate, difficulty: difficulty)
        
        if tasksByDate[dateString] != nil {
            tasksByDate[dateString]?.append(task)
            tasksByDate[dateString]?.sort { $0.difficulty > $1.difficulty }
        } else {
            tasksByDate[dateString] = [task]
        }
    }
    
    // Mark a task as complete
    func markTaskAsComplete(_ task: Task) {
        // Check if the task is not already marked as complete
        if !completedTasks.contains(where: { $0.name == task.name }) {
            completedTasks.append(task)
        }
    }
    
    // Delete a task
    func deleteTask(_ task: Task) {
        tasksByDate.forEach { date, tasks in
            tasksByDate[date] = tasks.filter { $0.id != task.id }
        }
        completedTasks.removeAll { $0.id == task.id }
    }
}

struct ScheduleView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var viewModel = ScheduleViewModel.shared
    
    // An array that will store the tasks
    @State private var tasks = [String]()
    
    @State private var addTaskPressed = false
    @State private var selectedTask: ScheduleViewModel.Task?
    
    // Function to get the dates for the current week
    func getDatesForCurrentWeek() -> [String] {
        let calendar = Calendar.current
        let now = Date()
        
        guard let startDate = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let endDate = calendar.date(byAdding: .day, value: 6, to: startDate) else {
            return []
        }
        
        var currentDate = startDate
        var dates: [String] = []
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        
        while currentDate <= endDate {
            dates.append(dateFormatter.string(from: currentDate))
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
        }
        
        return dates
    }
    
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .center) {
            // Create sections for each day of the week
            let days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            let datesForCurrentWeek = getDatesForCurrentWeek()
            
            ScrollView(.horizontal) {
                LazyHGrid(rows: [GridItem(.fixed(400), spacing: 20)], spacing: 16) {
                    ForEach(0..<days.count, id: \.self) { index in
                        createDayColumn(day: days[index], date: datesForCurrentWeek[index])
                    }
                }
                .padding()
                .background(Color.black)
            }
            .background(Color.black)
            // Display the task action sheet if a task is selected
            .actionSheet(item: $selectedTask) { task in
                createTaskActionSheet(for: task)
            }
        }
    }
    
    private func createDayColumn(day: String, date: String) -> some View {
        VStack {
            Text(day)
                .foregroundColor(.white)
                .font(.system(size: 25))
            Text(date)
                .foregroundColor(.teal)
                .font(.system(size: 22))
            ScrollView {
                LazyVGrid(columns: [GridItem(.fixed(150), spacing: 8)], spacing: 16) {
                    // Display tasks for the corresponding date, sorted by difficulty
                    ForEach((viewModel.tasksByDate[date] ?? []).sorted { task1, task2 in
                        // Sort by difficulty (descending order)
                        task1.difficulty > task2.difficulty
                    }, id: \.name) { task in
                        createTaskButton(for: task)
                    }
                }
                .padding()
            }
        }
        .offset(y: -150)
    }
    
    private func createTaskButton(for task: ScheduleViewModel.Task) -> some View {
        Button(action: {
            // Handle task selection
            selectedTask = task
        }) {
            Text("\(task.name) - Due: \(task.dueDate, formatter: dateFormatter)")
                .frame(width: 175, height: 75)
                .background(Color.white)
                .cornerRadius(10)
                .foregroundColor(.indigo)
        }
    }
    
    private func createTaskActionSheet(for task: ScheduleViewModel.Task) -> ActionSheet {
        ActionSheet(title: Text("Task Actions"), buttons: [
            .default(Text("Mark as Complete"), action: {
                // Handle marking the task as complete
                viewModel.markTaskAsComplete(task)
            }),
            .destructive(Text("Delete Task"), action: {
                // Handle deleting the task
                viewModel.deleteTask(task)
            }),
            .cancel()
        ])
    }
}

// View all tasks whether completed or still needs to get done
struct AllView: View {
    @ObservedObject private var viewModel = ScheduleViewModel.shared
    @State private var completedTaskNames = Set<String>()
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("To Do")) {
                    ForEach(viewModel.tasksByDate.keys.sorted(), id: \.self) { date in
                        if let tasks = viewModel.tasksByDate[date] {
                            ForEach(tasks.filter { !completedTaskNames.contains($0.name) }) { task in
                                TaskRow(task: task, markTaskAsComplete: markTaskAsComplete)
                            }
                        }
                    }
                }
                
                Section(header: Text("Completed")) {
                    ForEach(viewModel.completedTasks) { task in
                        TaskRow(task: task)
                    }
                }
            }
            .navigationBarTitle("All Tasks")
        }
        .onAppear {
            // Initialize completed task names
            completedTaskNames = Set(viewModel.completedTasks.map { $0.name })
        }
        .navigationViewStyle(StackNavigationViewStyle()) // Optional: Use StackNavigationViewStyle
        .edgesIgnoringSafeArea(.all) 
    }
    
    private func markTaskAsComplete(_ task: ScheduleViewModel.Task) {
        viewModel.markTaskAsComplete(task)
        completedTaskNames.insert(task.name)
    }
}

struct TaskRow: View {
    let task: ScheduleViewModel.Task
    var markTaskAsComplete: (ScheduleViewModel.Task) -> Void = { _ in }
    
    var body: some View {
        HStack {
            Text("\(task.name) - Due: \(formattedDate)")
                .foregroundColor(task.isCompleted ? .white : .indigo)
                .strikethrough(task.isCompleted)
            Spacer()
            if !task.isCompleted {
                Button(action: {
                    markTaskAsComplete(task)
                }) {
                    Text("Complete")
                        .foregroundColor(.teal)
                }
            }
        }
    }
    
    private var formattedDate: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM d, yyyy"
        return dateFormatter.string(from: task.dueDate)
    }
}

