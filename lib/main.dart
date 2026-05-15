import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/add_edit_task_screen.dart';
import 'services/auth_service.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'widgets/quote_card.dart';
import 'models/task.dart';
import 'widgets/task_card.dart';
import 'services/task_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TaskApp());
}


class TaskApp extends StatelessWidget {
  const TaskApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskFlow',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    const seedColor = Color(0xFF6C63FF);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
        primary: seedColor,
        secondary: const Color(0xFF00C8B0),
        tertiary: const Color(0xFFFF6584),
      ),
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5FF),
      cardColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? const Color(0xFF0F0F1A) : const Color(0xFFF5F5FF),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(
          color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService().authStateChanges,
      builder: (context, snapshot) {
        // While determining auth state, show a branded splash
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // Logged in → go to home; else → login
        if (snapshot.hasData && snapshot.data != null) {
          return HomeScreen(user: snapshot.data!);
        }
        return const LoginScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primary.withOpacity(0.35),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                color: Colors.white,
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'TaskFlow',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 32),
            CircularProgressIndicator(color: primary, strokeWidth: 2.5),
          ],
        ),
      ),
    );
  }
}

enum TaskFilter { all, pending, completed }

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  final AuthService _authService = AuthService();

  TaskFilter _filter = TaskFilter.all;
  late TabController _tabController;
  String? _storedUsername;

  
  StreamSubscription<List<Task>>? _tasksSub;
  List<Task> _allTasks = [];
  bool _tasksLoading = true;
  String? _tasksError;

  @override
  void initState() {
    super.initState();

    
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _filter = TaskFilter.values[_tabController.index]);
      }
    });

    
    _tasksSub = _taskService.getTasksStream(widget.user.uid).listen(
      (tasks) {
        if (mounted) {
          setState(() {
            _allTasks = tasks;
            _tasksLoading = false;
            _tasksError = null;
          });
        }
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _tasksError = e.toString();
            _tasksLoading = false;
          });
        }
      },
    );

    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final data = await _authService.getUserData(widget.user.uid);
    if (mounted && data != null) {
      setState(() => _storedUsername = data['username'] as String?);
    }
  }

  @override
  void dispose() {
    _tasksSub?.cancel();
    _tabController.dispose();
    super.dispose();
  }



  List<Task> _applyFilter(List<Task> tasks) {
    switch (_filter) {
      case TaskFilter.pending:
        return tasks.where((t) => !t.isCompleted).toList();
      case TaskFilter.completed:
        return tasks.where((t) => t.isCompleted).toList();
      case TaskFilter.all:
        return tasks;
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  String _displayName() {

    if (_storedUsername != null && _storedUsername!.isNotEmpty) {
      return _storedUsername!;
    }
    
    final name = widget.user.displayName;
    if (name != null && name.isNotEmpty) return name;
  
    final emailPrefix = (widget.user.email ?? '').split('@').first;
    if (emailPrefix.isEmpty) return '?';
    return emailPrefix[0].toUpperCase() + emailPrefix.substring(1);
  }


  Future<void> _confirmDelete(BuildContext ctx, Task task) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Task'),
        content: Text('Are you sure you want to delete "${task.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _taskService.deleteTask(task.id);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _authService.signOut();
  }

  void _openAddTask() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditTaskScreen(userId: widget.user.uid),
      ),
    );
  }

  void _openEditTask(Task task) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditTaskScreen(task: task, userId: widget.user.uid),
      ),
    );
  }



  Widget _buildBody(ThemeData theme) {
   
    if (_tasksLoading) {
      return Center(
        child: CircularProgressIndicator(color: theme.colorScheme.primary),
      );
    }

    if (_tasksError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: theme.colorScheme.error, size: 48),
            const SizedBox(height: 12),
            Text('Something went wrong', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              _tasksError!,
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    
    final filtered = _applyFilter(_allTasks);
    final totalCount = _allTasks.length;
    final completedCount = _allTasks.where((t) => t.isCompleted).length;
    final pendingCount = totalCount - completedCount;

    return CustomScrollView(
      slivers: [
       
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: QuoteCard(),
          ),
        ),

        
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _StatChip(
                  label: 'Total',
                  count: totalCount,
                  icon: Icons.list_alt_rounded,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Pending',
                  count: pendingCount,
                  icon: Icons.radio_button_unchecked_rounded,
                  color: theme.colorScheme.tertiary,
                ),
                const SizedBox(width: 10),
                _StatChip(
                  label: 'Done',
                  count: completedCount,
                  icon: Icons.check_circle_rounded,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
          ),
        ),

       
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withOpacity(0.6),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'All'),
                  Tab(text: 'Pending'),
                  Tab(text: 'Completed'),
                ],
              ),
            ),
          ),
        ),

        
        filtered.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: _EmptyState(filter: _filter),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final task = filtered[i];
                    return TaskCard(
                      task: task,
                      onToggleComplete: () =>
                          _taskService.toggleTaskCompletion(task),
                      onEdit: () => _openEditTask(task),
                      onDelete: () => _confirmDelete(ctx, task),
                    );
                  },
                ),
              ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _greeting(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _displayName(),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          // Profile / sign-out button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _signOut,
              child: CircleAvatar(
                radius: 20,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                child: Text(
                  _displayName().isNotEmpty
                      ? _displayName()[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: _buildBody(theme),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddTask,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'New Task',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
    );
  }
}



class _StatChip extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;

  const _StatChip({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withOpacity(0.55),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



class _EmptyState extends StatelessWidget {
  final TaskFilter filter;

  const _EmptyState({required this.filter});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String message;
    IconData icon;

    switch (filter) {
      case TaskFilter.pending:
        message = 'No pending tasks.\nYou\'re all caught up! 🎉';
        icon = Icons.task_alt_rounded;
        break;
      case TaskFilter.completed:
        message = 'No completed tasks yet.\nStart checking things off!';
        icon = Icons.check_circle_outline_rounded;
        break;
      case TaskFilter.all:
        message = 'No tasks yet.\nTap the button below to add one!';
        icon = Icons.inbox_rounded;
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 72,
              color: theme.colorScheme.primary.withOpacity(0.25),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: theme.colorScheme.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
