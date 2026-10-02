import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Catalog data should come from the backend `games` table; one entry is bundled for now.
class GamesCatalogScreen extends StatelessWidget {
  const GamesCatalogScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(title: const Text('Games'), bottom: const TabBar(tabs: [Tab(text: 'Featured'), Tab(text: 'Popular'), Tab(text: 'New'), Tab(text: 'All Games')])),
          body: TabBarView(children: [for (var i = 0; i < 4; i++) ListView(padding: const EdgeInsets.all(16), children: [
            Card(child: ListTile(leading: const Icon(Icons.grid_view_rounded), title: const Text('Fruit Party 5x5'), subtitle: const Text('Match fruit clusters'), onTap: () => context.push('/games-play'))),
          ])]),
        ),
      );
}
