import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'app.dart';
import 'database.dart';
import 'design.dart';
import 'store.dart';

SemanticsHandle? accessibility;
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  accessibility = SemanticsBinding.instance.ensureSemantics();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<BloomStore> startup = initialize();
  Future<BloomStore> initialize() async {
    try {
      final store = BloomStore(await openBloomDatabase());
      await store.load();
      return store;
    } catch (error, stack) {
      debugPrint('Bloom database initialization: $error\n$stack');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<BloomStore>(
    future: startup,
    builder: (context, snapshot) {
      if (snapshot.hasData) return BloomApp(store: snapshot.data!);
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: bloomTheme(),
        darkTheme: bloomTheme(brightness: Brightness.dark),
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'bloom',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 24),
                    if (!snapshot.hasError)
                      const CircularProgressIndicator()
                    else ...[
                      const Text(
                        kIsWeb
                            ? 'Не удалось открыть локальную базу. Проверьте, разрешено ли браузеру хранить данные.'
                            : 'Не удалось открыть журнал на устройстве. Проверьте свободное место и попробуйте ещё раз. Не удаляйте приложение: в нём хранятся ваши записи.',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => setState(() => startup = initialize()),
                        child: const Text('Попробовать ещё раз'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
