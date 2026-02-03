import 'package:flutter/material.dart';
import '../models/workout_model.dart';


// --- 下面是独立的组件，负责渲染每个动作卡片 ---

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final Function(int setIndex) onSetToggle; // 回调函数
  final VoidCallback onAddSet;
  /// 从今日训练中移除（计划项仅隐藏，额外项会从当日数据删除）
  final VoidCallback? onRemove;
  /// 编辑此动作（仅对当日额外动作有效）
  final VoidCallback? onEdit;
  /// 编辑/删除单个 set
  final Function(int setIndex)? onEditSet;
  final Function(int setIndex)? onDeleteSet;
  /// 标记是否为“当日额外动作”
  final bool isExtra;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onSetToggle,
    required this.onAddSet,
    this.onRemove,
    this.onEdit,
    this.onEditSet,
    this.onDeleteSet,
    this.isExtra = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalSets = exercise.sets.length;
    final totalReps = exercise.sets.fold<int>(0, (sum, s) => sum + s.reps);
    final totalVolume = exercise.sets.fold<double>(0, (sum, s) => sum + (s.weight * s.reps));
    final completedSets = exercise.sets.where((s) => s.isCompleted).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 动作名称
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        exercise.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isExtra)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFBB86FC).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          "EXTRA",
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFFBB86FC),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              (onRemove != null || onEdit != null)
                  ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey),
                      color: const Color(0xFF2C2C2C),
                      onSelected: (value) {
                        if (value == 'remove') onRemove?.call();
                        if (value == 'edit') onEdit?.call();
                      },
                      itemBuilder: (context) => [
                        if (onRemove != null)
                          const PopupMenuItem(
                            value: 'remove',
                            child: Text('从今日训练中移除', style: TextStyle(color: Colors.white70)),
                          ),
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('编辑', style: TextStyle(color: Colors.white70)),
                          ),
                      ],
                    )
                  : IconButton(
                      icon: const Icon(Icons.more_horiz, color: Colors.grey),
                      onPressed: () {},
                    )
            ],
          ),
          const SizedBox(height: 12),

          // 小结信息
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip("Sets", "$completedSets/$totalSets"),
              _buildStatChip("Reps", "$totalReps"),
              _buildStatChip("Volume", totalVolume.toStringAsFixed(0)),
            ],
          ),

          const SizedBox(height: 12),
          Divider(color: Colors.white.withOpacity(0.06)),
          const SizedBox(height: 8),
          
          // 表头 (Set | Previous | Weight | Reps | Done)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(
              children: [
                _buildHeader("SET", width: 40),
                _buildHeader("KG", flex: 1),
                _buildHeader("REPS", flex: 1),
                const SizedBox(width: 40), // Checkbox 占位
              ],
            ),
          ),

          // 组数列表
          ...List.generate(exercise.sets.length, (index) {
            final set = exercise.sets[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: set.isCompleted
                    ? Colors.green.withOpacity(0.12)
                    : Colors.white.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  // 1. 组号
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        color: set.isCompleted ? Colors.green : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 2. 重量
                  Expanded(
                    child: _buildValuePill("${set.weight} kg"),
                  ),

                  // 3. 次数
                  Expanded(
                    child: _buildValuePill("${set.reps} reps"),
                  ),

                  // 4. Set 操作
                  if (onEditSet != null || onDeleteSet != null)
                    PopupMenuButton<String>(
                      icon: Icon(Icons.more_vert, color: Colors.white.withOpacity(0.4), size: 18),
                      color: const Color(0xFF2C2C2C),
                      onSelected: (value) {
                        if (value == 'edit') onEditSet?.call(index);
                        if (value == 'delete') onDeleteSet?.call(index);
                      },
                      itemBuilder: (context) => [
                        if (onEditSet != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('编辑此组', style: TextStyle(color: Colors.white70)),
                          ),
                        if (onDeleteSet != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('删除此组', style: TextStyle(color: Colors.white70)),
                          ),
                      ],
                    ),

                  // 5. 复选框 (核心交互)
                  SizedBox(
                    width: 40,
                    child: Checkbox(
                      value: set.isCompleted,
                      activeColor: const Color(0xFFBB86FC), // 选中后的紫色
                      checkColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      onChanged: (val) {
                        onSetToggle(index); // 触发父组件更新
                      },
                    ),
                  ),
                ],
              ),
            );
          }),
          
          // 添加组数按钮
          Center(
            child: TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add, size: 16, color: Colors.grey),
              label: const Text(
                "Add Set",
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildHeader(String text, {double? width, int? flex}) {
    Widget child = Center(
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.grey,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    
    if (flex != null) return Expanded(flex: flex, child: child);
    return SizedBox(width: width, child: child);
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$label $value",
        style: TextStyle(
          fontSize: 11,
          color: Colors.white.withOpacity(0.7),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildValuePill(String text) {
    return Container(
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}