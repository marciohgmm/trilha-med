import 'dart:async';

import 'package:flutter_application_1/domain/platform/models/platform_entitlement.dart';
import 'package:flutter_application_1/domain/platform/models/subscription.dart';
import 'package:flutter_application_1/domain/platform/models/subscription_plan.dart';
import 'package:flutter_application_1/domain/platform/repositories/platform_repository_contracts.dart';

class FakeSubscriptionRepository implements SubscriptionRepository {
  FakeSubscriptionRepository({Subscription? initial}) {
    if (initial != null) _active = initial;
  }

  Subscription? _active;
  final _controller = StreamController<Subscription?>.broadcast();

  void emit(Subscription? subscription) {
    _active = subscription;
    _controller.add(subscription);
  }

  @override
  Stream<Subscription?> watchActiveForUser(String userId) async* {
    yield _active;
    yield* _controller.stream;
  }

  @override
  Stream<List<Subscription>> watchForUser(String userId, {int limit = 20}) =>
      Stream.value(_active == null ? [] : [_active!]);

  @override
  Stream<List<Subscription>> watchAll({int limit = 200}) =>
      Stream.value(_active == null ? [] : [_active!]);

  @override
  Future<Subscription?> getById(String id) async => _active;

  @override
  Future<String> save(Subscription subscription) async {
    emit(subscription);
    return subscription.id;
  }
}

class FakeEntitlementRepository implements EntitlementRepository {
  FakeEntitlementRepository([List<PlatformEntitlement>? initial])
      : _list = List.of(initial ?? []);

  List<PlatformEntitlement> _list;
  final _controller = StreamController<List<PlatformEntitlement>>.broadcast();

  void emit(List<PlatformEntitlement> list) {
    _list = List.of(list);
    _controller.add(_list);
  }

  @override
  Stream<List<PlatformEntitlement>> watchForUser(String userId) async* {
    yield _list;
    yield* _controller.stream;
  }

  @override
  Future<String> save(String userId, PlatformEntitlement entitlement) async =>
      entitlement.id;

  @override
  Future<void> deactivate(String userId, String entitlementId) async {}
}

class FakeSubscriptionPlanRepository implements SubscriptionPlanRepository {
  FakeSubscriptionPlanRepository({this.plan});

  final SubscriptionPlan? plan;

  @override
  Future<SubscriptionPlan?> getById(String id) async => plan;

  @override
  Stream<List<SubscriptionPlan>> watchActivePlans() =>
      Stream.value(plan == null ? [] : [plan!]);

  @override
  Stream<List<SubscriptionPlan>> watchAllPlans() =>
      Stream.value(plan == null ? [] : [plan!]);

  @override
  Future<String> save(SubscriptionPlan plan) async => plan.id;

  @override
  Future<void> delete(String id) async {}
}
