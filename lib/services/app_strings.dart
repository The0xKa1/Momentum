import 'package:flutter/material.dart';

class AppStrings {
  AppStrings(this.locale);

  final Locale locale;

  static AppStrings of(BuildContext context) {
    return AppStrings(Localizations.localeOf(context));
  }

  bool get _isZh => locale.languageCode == 'zh';

  String get workout => _isZh ? '训练' : 'Workout';
  String get plan => _isZh ? '计划' : 'Plan';
  String get diet => _isZh ? '饮食' : 'Diet';
  String get dietComingSoon => _isZh ? '饮食（即将上线）' : 'Diet Page (Coming Soon)';
  String get settings => _isZh ? '设置' : 'Settings';
  String get about => _isZh ? '关于' : 'About';
  String get aboutStorageHint => _isZh ? '数据保存在本地，更新应用后仍会保留。' : 'Data is stored locally and will remain after updates.';

  String get planSettings => _isZh ? '计划设置' : 'Plan Settings';
  String get languageSetting => _isZh ? '语言' : 'Language';
  String get languageSettingLabel => _isZh ? 'Language / 语言' : 'Language / 语言';
  String get followSystem => _isZh ? '跟随系统' : 'System';
  String get chineseSimplified => _isZh ? '中文（简体）' : 'Chinese (Simplified)';
  String get english => _isZh ? '英文' : 'English';

  String get noPlansYet => _isZh ? '暂无计划，点击 + 创建' : 'No plans yet. Tap + to create one.';
  String get newPlan => _isZh ? '新建计划' : 'NEW PLAN';
  String get editPlan => _isZh ? '编辑计划' : 'EDIT PLAN';
  String get planName => _isZh ? '计划名称' : 'Plan name';
  String get exercise => _isZh ? '动作' : 'Exercise';
  String get exerciseName => _isZh ? '动作名称' : 'Exercise name';
  String get exerciseType => _isZh ? '动作类型' : 'Exercise Type';
  String get freeExercise => _isZh ? '自定义动作' : 'Custom Exercise';
  String get weightedExercise => _isZh ? '负重动作' : 'Weighted Exercise';
  String get timedExercise => _isZh ? '计时动作' : 'Timed Exercise';
  String get customFields => _isZh ? '自定义字段' : 'Custom Fields';
  String get fieldName => _isZh ? '字段名' : 'Field Name';
  String get fieldValue => _isZh ? '字段值' : 'Field Value';
  String get addField => _isZh ? '+ 添加字段' : '+ Add Field';
  String weightLabel(String unit) => _isZh ? '重量（$unit）' : 'Weight ($unit)';
  String get weightUnitSetting => _isZh ? '重量单位' : 'Weight Unit';
  String get kilograms => _isZh ? '千克（kg）' : 'Kilograms (kg)';
  String get pounds => _isZh ? '磅（lb）' : 'Pounds (lb)';
  String get reps => _isZh ? '次数' : 'Reps';
  String get count => _isZh ? '个数' : 'Count';
  String get duration => _isZh ? '时间（秒）' : 'Duration (sec)';
  String get distance => _isZh ? '距离' : 'Distance';
  String get sets => _isZh ? '组数' : 'Sets';
  String get addExercise => _isZh ? '+ 添加动作' : '+ Add Exercise';
  String get savePlan => _isZh ? '保存计划' : 'SAVE PLAN';
  String get pleaseEnterPlanName => _isZh ? '请输入计划名称' : 'Please enter plan name';
  String get completeExerciseFields => _isZh ? '请完善动作信息' : 'Please complete all exercise fields';

  String get selectPlan => _isZh ? '选择计划' : 'SELECT PLAN';
  String get noPlanTemplatesYet => _isZh ? '暂无计划模板' : 'No plan templates yet.';
  String get goToPlanSettings => _isZh ? '去计划设置' : 'Go to Plan Settings';
  String get schedule => _isZh ? '日程' : 'SCHEDULE';
  String get planDetails => _isZh ? '计划详情' : 'PLAN DETAILS';
  String get viewPlanDetails => _isZh ? '查看详情' : 'View Details';
  String get noPlanDetails => _isZh ? '该日期暂无可展示的具体动作' : 'No detailed exercises for this day';
  String get restDay => _isZh ? '休息日' : 'Rest Day';
  String get planDeleted => _isZh ? '计划已删除' : 'Plan deleted';
  String get greatJob => _isZh ? '干得漂亮！' : 'Great job!';
  String get completedAllPlans => _isZh ? '今天的计划已全部完成，加油！' : "You've completed all plans for today. Keep it up!";
  String get ok => _isZh ? '好的' : 'OK';

  String get todaysSession => _isZh ? '今日训练' : "TODAY'S SESSION";
  String get restRecover => _isZh ? '休息与恢复' : 'Rest & Recover';
  String get restingWait => _isZh ? '休息中，请稍候' : 'Resting... Please wait';
  String get restFinished => _isZh ? '休息结束！' : 'Rest Finished!';
  String get timeForNextSet => _isZh ? '该进行下一组了！' : 'Time for the next set!';
  String get gotIt => _isZh ? '知道了' : 'GOT IT';
  String get addSet => _isZh ? '新增一组' : 'Add Set';
  String get editSet => _isZh ? '编辑一组' : 'Edit Set';
  String get cancel => _isZh ? '取消' : 'CANCEL';
  String get add => _isZh ? '添加' : 'ADD';
  String get save => _isZh ? '保存' : 'SAVE';
  String get pleaseEnterValidNumbers => _isZh ? '请输入有效数字' : 'Please enter valid numbers';
  String get pleaseSelectPlanFirst => _isZh ? '请先选择今天的计划' : 'Please select a plan for today first';
  String get addExtraExercise => _isZh ? '添加额外动作' : 'ADD EXTRA EXERCISE';
  String get editExtraExercise => _isZh ? '编辑额外动作' : 'EDIT EXTRA EXERCISE';
  String get restingTitle => _isZh ? '休息中...' : 'Resting...';
  String get countdownInProgress => _isZh ? '倒计时进行中' : 'Countdown in progress';

  String get restTimeOverTitle => _isZh ? '休息结束！🏋️' : 'Rest Time Over! 🏋️';
  String get restTimeOverBody => _isZh ? '该进行下一组了！' : 'Time for your next set!';
  String get restLabel => _isZh ? '休息' : 'REST';
  String get selectRestTime => _isZh ? '选择休息时间' : 'Select Rest Time';
  String get skipRest => _isZh ? '跳过休息' : 'Skip Rest';

  String restSeconds(int seconds) => _isZh ? '$seconds 秒' : '${seconds}s';

  String get soundSetting => _isZh ? '铃声' : 'Sound';
  String get restSoundSetting => _isZh ? '休息铃声' : 'Rest Sound';
  String get chooseSound => _isZh ? '选择铃声' : 'Choose Sound';
  String get previewSound => _isZh ? '试听铃声' : 'Preview';
  String get stopPreview => _isZh ? '停止试听' : 'Stop Preview';
  String get defaultSound => _isZh ? '默认铃声' : 'Default';
  String get resetDefault => _isZh ? '恢复默认' : 'Reset';
  String get soundSelected => _isZh ? '已选择' : 'Selected';
  String get invalidSoundFile => _isZh ? '无法使用该音频文件' : 'Unable to use this audio file';
  String get soundPreviewFailed => _isZh ? '铃声试听失败' : 'Unable to preview this sound';
  String get soundForForegroundAndBackground => _isZh ? '前台倒计时与后台提醒都会使用该铃声' : 'Used for both in-app and background rest alarms';

  String get appearanceSetting => _isZh ? '配色' : 'Appearance';
  String get themeSchemeSetting => _isZh ? '配色方案' : 'Color Scheme';
  String get backgroundImageSetting => _isZh ? '背景图片' : 'Background Image';
  String get chooseBackgroundImage => _isZh ? '选择背景图' : 'Choose Image';
  String get clearBackgroundImage => _isZh ? '清除背景图' : 'Clear Image';
  String get noBackgroundImage => _isZh ? '未设置背景图' : 'No background image';
  String get backgroundImageSelected => _isZh ? '当前背景' : 'Current Background';
  String get backgroundOverlay => _isZh ? '遮罩强度' : 'Overlay';
  String get backgroundBlur => _isZh ? '模糊程度' : 'Blur';
  String get backgroundImageHint => _isZh ? '背景图会在全局生效，并自动叠加深色遮罩以保证可读性' : 'The image is applied globally with a dark overlay for readability';
  String get customThemeScheme => _isZh ? '自定义方案' : 'Custom Scheme';
  String get accentColor => _isZh ? '强调色' : 'Accent';
  String get backgroundColor => _isZh ? '背景色' : 'Background';
  String get surfaceColor => _isZh ? '卡片色' : 'Surface';
  String get editColor => _isZh ? '编辑颜色' : 'Edit Color';
  String get saveThemeScheme => _isZh ? '保存配色' : 'Save Scheme';
  String get presetSpiderVerse => _isZh ? '纵横宇宙' : 'Spider-Verse';
  String get presetMidnightOrchid => _isZh ? '午夜紫' : 'Midnight Orchid';
  String get presetEmberCore => _isZh ? '余烬橙' : 'Ember Core';
  String get presetGlacierMint => _isZh ? '冰川薄荷' : 'Glacier Mint';
  String get presetVoltLime => _isZh ? '电光青柠' : 'Volt Lime';

  String get links => _isZh ? '链接' : 'Links';
  String get projectWebsite => _isZh ? '项目网站' : 'Project Website';
  String get openWebsite => _isZh ? '打开网站' : 'Open Website';
  String get openWebsiteFailed => _isZh ? '无法打开网站' : 'Unable to open website';

  String get appTitle => 'Momentum';
  String get splashSubtitle => _isZh ? '持续向前' : 'KEEP MOVING FORWARD';
}
