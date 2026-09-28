import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:muscle_monitoring/presentation/providers/page_index_provider.dart';
import 'package:muscle_monitoring/presentation/screens/ble_screen.dart';
import 'package:muscle_monitoring/presentation/screens/monitoring_screen.dart';
import 'package:muscle_monitoring/presentation/widgets/shared/custom_bottom_navigation.dart';

class HomeScreen extends ConsumerStatefulWidget {
  static const name = 'home-screen';

  const HomeScreen({super.key, this.initialPage = 0});
  final int initialPage;
  @override
  ConsumerState<HomeScreen> createState() => _HomeState();
}

class _HomeState extends ConsumerState<HomeScreen> {
  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPage != widget.initialPage) {
      Future.microtask(() {
        if (mounted) {
          ref.read(pageIndexProvider.notifier).state = widget.initialPage;
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(pageIndexProvider.notifier).state = widget.initialPage;
      }
    });
  }

  final viewRoutes = const <Widget>[BleScreen(), MonitoringScreen()];

  @override
  Widget build(BuildContext context) {
    final pageIndex = ref.watch(pageIndexProvider);
    return Scaffold(
      body: IndexedStack(index: pageIndex, children: viewRoutes),
      bottomNavigationBar: CustomBottomNavigation(),
    );
  }
}
