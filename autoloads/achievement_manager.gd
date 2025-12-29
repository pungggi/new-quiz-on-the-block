extends Node
class_name AchievementManagerClass

## Achievement Manager (Autoload)
## Tracks and unlocks achievements

signal achievement_unlocked(achievement: AchievementData)

## All defined achievements
var all_achievements: Array[AchievementData] = []

## Tracking values
var _current_streak: int = 0


func _ready() -> void:
	_define_achievements()
	
	# Connect to relevant signals
	var quiz_mgr: Node = get_node_or_null("/root/QuizManager")
	if quiz_mgr:
		quiz_mgr.quiz_completed.connect(_on_quiz_completed)
	
	var building_mgr: Node = get_node_or_null("/root/BuildingManager")
	if building_mgr:
		building_mgr.building_placed_event.connect(_on_building_placed)
	
	ProfileManager.profile_created.connect(_on_profile_created)
	ProfileManager.points_changed.connect(_on_points_changed)


func _define_achievements() -> void:
	all_achievements = [
		AchievementData.create("first_steps", "Erste Schritte", "Erstelle dein erstes Profil", "👶", AchievementData.Type.PROFILE_CREATED),
		AchievementData.create("quiz_beginner", "Quiz-Anfänger", "Beantworte 5 Fragen richtig", "📝", AchievementData.Type.QUIZ_CORRECT, 5),
		AchievementData.create("quiz_pro", "Quiz-Profi", "Beantworte 25 Fragen richtig", "🎓", AchievementData.Type.QUIZ_CORRECT, 25),
		AchievementData.create("quiz_master", "Quiz-Meister", "Beantworte 100 Fragen richtig", "🏆", AchievementData.Type.QUIZ_CORRECT, 100),
		AchievementData.create("streak_3", "Auf einer Rolle", "3 richtige Antworten hintereinander", "🔥", AchievementData.Type.QUIZ_STREAK, 3),
		AchievementData.create("streak_5", "Unaufhaltsam", "5 richtige Antworten hintereinander", "⚡", AchievementData.Type.QUIZ_STREAK, 5),
		AchievementData.create("streak_10", "Perfektionist", "10 richtige Antworten hintereinander", "💎", AchievementData.Type.QUIZ_STREAK, 10),
		AchievementData.create("builder_1", "Baumeister", "Platziere dein erstes Gebäude", "🏠", AchievementData.Type.BUILDINGS_PLACED, 1),
		AchievementData.create("builder_5", "Stadtplaner", "Platziere 5 Gebäude", "🏘️", AchievementData.Type.BUILDINGS_PLACED, 5),
		AchievementData.create("builder_10", "Architekt", "Platziere 10 Gebäude", "🏙️", AchievementData.Type.BUILDINGS_PLACED, 10),
		AchievementData.create("rich_200", "Fleißig", "Erreiche 200 Punkte", "💰", AchievementData.Type.POINTS_EARNED, 200),
		AchievementData.create("rich_500", "Wohlhabend", "Erreiche 500 Punkte", "💎", AchievementData.Type.POINTS_EARNED, 500),
	]


## Check if achievement is unlocked
func is_unlocked(achievement_id: String) -> bool:
	if not ProfileManager.current_profile:
		return false
	return achievement_id in ProfileManager.current_profile.unlocked_achievements


## Get all unlocked achievements
func get_unlocked() -> Array[AchievementData]:
	var unlocked: Array[AchievementData] = []
	for ach in all_achievements:
		if is_unlocked(ach.id):
			unlocked.append(ach)
	return unlocked


## Get all locked achievements
func get_locked() -> Array[AchievementData]:
	var locked: Array[AchievementData] = []
	for ach in all_achievements:
		if not is_unlocked(ach.id):
			locked.append(ach)
	return locked


## Try to unlock an achievement
func try_unlock(achievement_id: String) -> bool:
	if is_unlocked(achievement_id):
		return false
	
	var achievement: AchievementData = null
	for ach in all_achievements:
		if ach.id == achievement_id:
			achievement = ach
			break
	
	if not achievement:
		return false
	
	# Unlock it
	ProfileManager.current_profile.unlocked_achievements.append(achievement_id)
	ProfileManager.add_points(achievement.points)
	ProfileManager.save_profile()
	
	achievement_unlocked.emit(achievement)
	return true


func _on_quiz_completed(was_correct: bool, _question: QuizQuestion) -> void:
	if was_correct:
		_current_streak += 1
		_check_quiz_achievements()
	else:
		_current_streak = 0


func _check_quiz_achievements() -> void:
	var profile: PlayerProfile = ProfileManager.current_profile
	if not profile:
		return
	
	var total_correct: int = profile.total_correct_answers
	
	# Check correct answer achievements
	for ach in all_achievements:
		if ach.type == AchievementData.Type.QUIZ_CORRECT:
			if total_correct >= ach.target_value:
				try_unlock(ach.id)
		elif ach.type == AchievementData.Type.QUIZ_STREAK:
			if _current_streak >= ach.target_value:
				try_unlock(ach.id)


func _on_building_placed(_pos: Vector3i, _building: BuildingData) -> void:
	var profile: PlayerProfile = ProfileManager.current_profile
	if not profile:
		return
	
	for ach in all_achievements:
		if ach.type == AchievementData.Type.BUILDINGS_PLACED:
			if profile.buildings_placed >= ach.target_value:
				try_unlock(ach.id)


func _on_profile_created(_profile: PlayerProfile) -> void:
	try_unlock("first_steps")


func _on_points_changed(new_total: int) -> void:
	for ach in all_achievements:
		if ach.type == AchievementData.Type.POINTS_EARNED:
			if new_total >= ach.target_value:
				try_unlock(ach.id)
