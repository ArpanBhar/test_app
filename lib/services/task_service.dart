import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task.dart';

class TaskService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'tasks';

  /// Real-time stream of tasks for a user
  Stream<List<Task>> getTasksStream(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Task.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Add a new task
  Future<void> addTask(Task task) async {
    try {
      await _firestore.collection(_collection).add(task.toMap());
    } catch (e) {
      throw 'Failed to add task: $e';
    }
  }

  /// Update an existing task
  Future<void> updateTask(Task task) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(task.id)
          .update(task.toMap());
    } catch (e) {
      throw 'Failed to update task: $e';
    }
  }

  /// Delete a task
  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore.collection(_collection).doc(taskId).delete();
    } catch (e) {
      throw 'Failed to delete task: $e';
    }
  }

  /// Toggle task completion status
  Future<void> toggleTaskCompletion(Task task) async {
    try {
      await _firestore.collection(_collection).doc(task.id).update({
        'isCompleted': !task.isCompleted,
      });
    } catch (e) {
      throw 'Failed to update task status: $e';
    }
  }
}
