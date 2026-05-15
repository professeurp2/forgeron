import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tutorial_data.dart';
import '../screens/main_scaffold.dart';

class TutorialState {
  final bool isActive;
  final int currentStepIndex;
  final bool isAnimating;

  TutorialState({
    this.isActive = false,
    this.currentStepIndex = 0,
    this.isAnimating = false,
  });

  TutorialState copyWith({
    bool? isActive,
    int? currentStepIndex,
    bool? isAnimating,
  }) {
    return TutorialState(
      isActive: isActive ?? this.isActive,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isAnimating: isAnimating ?? this.isAnimating,
    );
  }

  int get totalSteps => tutorialSteps.length;
}

final tutorialProvider = StateNotifierProvider<TutorialController, TutorialState>((ref) {
  return TutorialController(ref);
});

class TutorialController extends StateNotifier<TutorialState> {
  final Ref _ref;
  TutorialController(this._ref) : super(TutorialState());
  Future<void> checkAutoStart() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('tutorial_completed') ?? false;
    if (!completed) {
      start();
    }
  }

  void start() {
    state = state.copyWith(isActive: true, currentStepIndex: 0);
    _applyStepNavigation();
  }

  void next() {
    if (state.currentStepIndex < state.totalSteps - 1) {
      state = state.copyWith(currentStepIndex: state.currentStepIndex + 1);
      _applyStepNavigation();
    } else {
      complete();
    }
  }

  void previous() {
    if (state.currentStepIndex > 0) {
      state = state.copyWith(currentStepIndex: state.currentStepIndex - 1);
      _applyStepNavigation();
    }
  }

  void skip() {
    complete();
  }

  Future<void> complete() async {
    state = state.copyWith(isActive: false);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_completed', true);
  }

  void restart() {
    state = state.copyWith(isActive: true, currentStepIndex: 0);
    _applyStepNavigation();
  }

  void _applyStepNavigation() {
    final step = tutorialSteps[state.currentStepIndex];
    int pageIndex = 0;
    switch (step.page) {
      case 'dashboard': pageIndex = 0; break;
      case 'probing': pageIndex = 1; break;
      case 'tools': pageIndex = 2; break;
      case 'files': pageIndex = 3; break;
      case 'mdi': pageIndex = 4; break;
      case 'diagnostics': pageIndex = 5; break;
    }
    _ref.read(selectedNavIndexProvider.notifier).state = pageIndex;
  }
}
