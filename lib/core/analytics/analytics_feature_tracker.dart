import 'package:flutter/material.dart';

import '../../core/analytics/analytics_events.dart';
import '../../services/analytics/app_analytics_service.dart';

/// Rastreia abertura de feature uma vez por instância de tela.
mixin AnalyticsFeatureTracker<T extends StatefulWidget> on State<T> {
  bool _analyticsTracked = false;

  void trackFeatureOnce(
    String eventName, {
    Map<String, Object?> parameters = const {},
    String? userId,
  }) {
    if (_analyticsTracked) return;
    _analyticsTracked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppAnalyticsService.instance.logFeatureEvent(
        eventName,
        userId: userId,
        parameters: parameters,
      );
    });
  }
}

/// Helpers estáticos para telas sem mixin.
abstract final class AnalyticsFeatures {
  static void flashcards({String? userId, String? materia}) {
    AppAnalyticsService.instance.logFeatureEvent(
      AnalyticsEvents.flashcardStudyStart,
      userId: userId,
      parameters: {
        if (materia != null) AnalyticsParams.materia: materia,
      },
    );
  }

  static void questions({String? userId, String? materia, String? subtema}) {
    AppAnalyticsService.instance.logFeatureEvent(
      AnalyticsEvents.questionsStudyStart,
      userId: userId,
      parameters: {
        if (materia != null) AnalyticsParams.materia: materia,
        if (subtema != null) AnalyticsParams.subtema: subtema,
      },
    );
  }

  static void simuladoStart({String? userId, int? questionCount}) {
    AppAnalyticsService.instance.logFeatureEvent(
      AnalyticsEvents.simuladoStart,
      userId: userId,
      parameters: {
        if (questionCount != null) AnalyticsParams.questionCount: questionCount,
      },
    );
  }

  static void simuladoComplete({
    String? userId,
    double? scorePercent,
    int? questionCount,
  }) {
    AppAnalyticsService.instance.logFeatureEvent(
      AnalyticsEvents.simuladoComplete,
      userId: userId,
      parameters: {
        if (scorePercent != null) AnalyticsParams.scorePercent: scorePercent,
        if (questionCount != null) AnalyticsParams.questionCount: questionCount,
      },
    );
  }

  static void osceLobby({String? userId}) {
    AppAnalyticsService.instance.logFeatureEvent(
      AnalyticsEvents.osceLobbyOpen,
      userId: userId,
    );
  }

  static void osceStation({String? userId, String? roomId}) {
    AppAnalyticsService.instance.logFeatureEvent(
      AnalyticsEvents.osceStationStart,
      userId: userId,
      parameters: {if (roomId != null) AnalyticsParams.roomId: roomId},
    );
  }

  static void practicalPhase({String? userId, String? modelId}) {
    AppAnalyticsService.instance.logFeatureEvent(
      AnalyticsEvents.practicalPhaseOpen,
      userId: userId,
      parameters: {if (modelId != null) AnalyticsParams.modelId: modelId},
    );
  }

  static void liveEvent({String? userId, String? eventId}) {
    AppAnalyticsService.instance.logFeatureEvent(
      AnalyticsEvents.liveEventJoin,
      userId: userId,
      parameters: {if (eventId != null) AnalyticsParams.eventId: eventId},
    );
  }

  static void plansView({String? userId}) {
    AppAnalyticsService.instance.logFeatureEvent(
      AnalyticsEvents.plansView,
      userId: userId,
    );
  }
}
