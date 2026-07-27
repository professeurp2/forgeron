import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'tutorial_data.dart';
import 'tutorial_step.dart';
import '../screens/main_scaffold.dart';

class TutorialState {
  final bool isActive;
  final int currentStepIndex;
  final bool isAnimating;

  /// Le mobile suit son propre parcours : lui servir les étapes desktop
  /// revenait à surligner une barre latérale et un pied de page inexistants.
  final bool isMobile;

  TutorialState({
    this.isActive = false,
    this.currentStepIndex = 0,
    this.isAnimating = false,
    this.isMobile = false,
  });

  TutorialState copyWith({
    bool? isActive,
    int? currentStepIndex,
    bool? isAnimating,
    bool? isMobile,
  }) {
    return TutorialState(
      isActive: isActive ?? this.isActive,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      isAnimating: isAnimating ?? this.isAnimating,
      isMobile: isMobile ?? this.isMobile,
    );
  }

  /// Le parcours effectivement joué.
  List<TutorialStep> get steps =>
      isMobile ? mobileTutorialSteps : tutorialSteps;

  int get totalSteps => steps.length;
}

final tutorialProvider = StateNotifierProvider<TutorialController, TutorialState>((ref) {
  return TutorialController(ref);
});

class TutorialController extends StateNotifier<TutorialState> {
  final Ref _ref;
  TutorialController(this._ref) : super(TutorialState());
  Future<void> checkAutoStart({bool isMobile = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('tutorial_completed') ?? false;
    if (!completed) {
      start(isMobile: isMobile);
    }
  }

  /// Aligne le parcours sur la mise en page réellement affichée.
  ///
  /// Appelé par l'overlay quand il constate un écart : c'est le seul endroit
  /// qui connaisse la largeur réelle au moment de peindre. Si le parcours
  /// change, on repart de la première étape (les index ne se correspondent pas
  /// d'une liste à l'autre).
  void setLayout({required bool isMobile}) {
    if (state.isMobile == isMobile) return;
    state = state.copyWith(isMobile: isMobile, currentStepIndex: 0);
    _applyStepNavigation();
  }

  void start({bool isMobile = false}) {
    state = state.copyWith(
        isActive: true, currentStepIndex: 0, isMobile: isMobile);
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

  void restart({bool isMobile = false}) {
    state = state.copyWith(
        isActive: true, currentStepIndex: 0, isMobile: isMobile);
    _applyStepNavigation();
  }

  void _applyStepNavigation() {
    final step = state.steps[state.currentStepIndex];
    final int? pageIndex = switch (step.page) {
      'dashboard' => 0,
      'probing' => 1,
      'tools' => 2,
      'files' => 3,
      'mdi' => 4,
      'diagnostics' => 5,
      // 'settings' n'est pas une destination de la navigation : on reste où on
      // est plutôt que de renvoyer silencieusement au tableau de bord.
      _ => null,
    };
    if (pageIndex != null) {
      _ref.read(selectedNavIndexProvider.notifier).state = pageIndex;
    }
  }
}
