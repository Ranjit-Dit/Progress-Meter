import 'package:flutter/material.dart';

import '../../../common/app_theme.dart';
import '../data/ai_provider_client.dart';
import '../domain/ai_provider.dart';

/// A null dialog result cancels; a selection with no config uses the backend.
class AiProviderSelection {
  const AiProviderSelection(this.config);
  final AiProviderConfig? config;
}

Future<AiProviderSelection?> showAiProviderSettings(
  BuildContext context, {
  AiProviderConfig? current,
  Future<void> Function(AiProviderConfig)? testConnection,
}) => showDialog<AiProviderSelection>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _AiProviderDialog(current: current, testConnection: testConnection),
);

class AiProviderSettingsCard extends StatelessWidget {
  const AiProviderSettingsCard({
    super.key,
    this.current,
    required this.onConfigure,
  });

  final AiProviderConfig? current;
  final VoidCallback onConfigure;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.tune_rounded, color: AppColors.green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Your AI model',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    current == null
                        ? 'Using the app backend'
                        : '${current!.provider.label} · ${current!.model}',
                    key: const Key('ai-provider-status'),
                    style: const TextStyle(
                      color: AppColors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          current == null
              ? 'Connect your own AI provider and API key for this app session.'
              : 'Your personal key stays in memory for this app session and is excluded from backups.',
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const Key('ai-provider-configure'),
          onPressed: onConfigure,
          icon: const Icon(Icons.key_outlined, size: 18),
          label: Text(current == null ? 'Connect my AI' : 'Change AI settings'),
        ),
      ],
    ),
  );
}

class _AiProviderDialog extends StatefulWidget {
  const _AiProviderDialog({this.current, this.testConnection});
  final AiProviderConfig? current;
  final Future<void> Function(AiProviderConfig)? testConnection;

  @override
  State<_AiProviderDialog> createState() => _AiProviderDialogState();
}

class _AiProviderDialogState extends State<_AiProviderDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _model;
  late final TextEditingController _key;
  late final TextEditingController _baseUrl;
  late AiProvider _provider;
  bool _showKey = false;
  bool _testing = false;
  bool _verified = false;
  String? _error;
  int _revision = 0;
  AiProviderClient? _testingClient;

  @override
  void initState() {
    super.initState();
    final current = widget.current;
    _provider = current?.provider ?? AiProvider.openai;
    _model = TextEditingController(text: current?.model ?? '');
    _key = TextEditingController(text: current?.apiKey ?? '');
    _baseUrl = TextEditingController(
      text: current?.provider == AiProvider.custom
          ? current!.baseUrl.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _testingClient?.close();
    _model.dispose();
    _key.dispose();
    _baseUrl.dispose();
    super.dispose();
  }

  void _changed([String? _]) => setState(() {
    _revision++;
    _verified = false;
    _error = null;
  });

  void _changeProvider(AiProvider? value) {
    if (value == null || value == _provider || _testing) return;
    setState(() {
      _provider = value;
      // A credential belongs to one provider, not to whichever is chosen next.
      _key.clear();
      _showKey = false;
      _revision++;
      _verified = false;
      _error = null;
    });
  }

  String get _destination {
    if (_provider != AiProvider.custom) {
      return _provider.defaultBaseUrl?.host ?? _provider.label;
    }
    final uri = Uri.tryParse(_baseUrl.text.trim());
    return uri != null && uri.host.isNotEmpty
        ? uri.host
        : 'your HTTPS endpoint';
  }

  AiProviderConfig? _configuration() {
    if (!_form.currentState!.validate()) return null;
    try {
      return AiProviderConfig(
        provider: _provider,
        model: _model.text.trim(),
        apiKey: _key.text.trim(),
        baseUrl: _provider == AiProvider.custom
            ? Uri.parse(_baseUrl.text.trim())
            : null,
      );
    } catch (_) {
      setState(() {
        _error = 'Check the provider, model ID, API key, and endpoint.';
      });
      return null;
    }
  }

  String _testError(Object error) {
    if (error is AiProviderException) {
      return switch (error.code) {
        'upstream_auth' ||
        'unauthorized' ||
        'authentication' ||
        'invalid_key' => 'The provider rejected the key or model. Check your key and model access.',
        'rate_limited' || 'upstream_rate_limited' =>
          'The provider is at its usage limit. Check API billing or try later.',
        'timeout' => 'The connection timed out. Try again when you are online.',
        'unsupported' || 'unsupported_model' || 'invalid_response' => 'This model could not return the structured response the app needs. Check its JSON or tool support.',
        _ => 'Could not verify this connection. Check the provider, model ID, endpoint, and key.',
      };
    }
    // Provider errors may contain credentials. Never render arbitrary errors.
    return 'Could not verify this connection. Check the provider, model ID, endpoint, and key.';
  }

  Future<void> _test() async {
    if (_testing) return;
    final config = _configuration();
    if (config == null) return;
    final revision = _revision;
    setState(() {
      _testing = true;
      _verified = false;
      _error = null;
    });
    try {
      if (widget.testConnection case final test?) {
        await test(config);
      } else {
        final client = AiProviderClient(config: config);
        _testingClient = client;
        await client.testConnection();
      }
      if (!mounted || revision != _revision) return;
      setState(() => _verified = true);
    } catch (error) {
      if (!mounted || revision != _revision) return;
      setState(() => _error = _testError(error));
    } finally {
      _testingClient?.close();
      _testingClient = null;
      if (mounted) setState(() => _testing = false);
    }
  }

  void _useKey() {
    if (_testing) return;
    final config = _configuration();
    if (config != null) {
      Navigator.of(context).pop(AiProviderSelection(config));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_testing,
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CHOOSE YOUR AI',
                            style: TextStyle(
                              fontSize: 10,
                              letterSpacing: 1.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.green,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your model. Your key.',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: const Key('personal-ai-close'),
                      tooltip: 'Close AI settings',
                      onPressed: _testing
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Use your own provider for coaching, tests, grading, and progress reviews.',
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 22),
                DropdownButtonFormField<AiProvider>(
                  key: const Key('personal-ai-provider'),
                  initialValue: _provider,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'AI provider'),
                  items: [
                    for (final provider in AiProvider.values)
                      DropdownMenuItem(
                        value: provider,
                        child: Text(
                          provider.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: _testing ? null : _changeProvider,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('personal-ai-model'),
                  controller: _model,
                  enabled: !_testing,
                  autocorrect: false,
                  enableSuggestions: false,
                  textCapitalization: TextCapitalization.none,
                  onChanged: _changed,
                  decoration: const InputDecoration(
                    labelText: 'Model ID',
                    helperText: 'Use the exact model ID from your provider.',
                    helperMaxLines: 3,
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Enter a model ID.';
                    if (text.length > 100) {
                      return 'Use a model ID up to 100 characters.';
                    }
                    if (text.contains(RegExp(r'[\x00-\x20\x7f]'))) {
                      return 'Use the provider’s exact model ID.';
                    }
                    return null;
                  },
                ),
                if (_provider == AiProvider.custom) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('personal-ai-base-url'),
                    controller: _baseUrl,
                    enabled: !_testing,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) {
                      // Moving a key to a different host requires a new paste.
                      _key.clear();
                      _changed();
                    },
                    decoration: const InputDecoration(
                      labelText: 'API base URL',
                      hintText: 'https://your-provider.example/v1',
                      helperText: 'An OpenAI-compatible Chat Completions API.',
                      helperMaxLines: 3,
                    ),
                    validator: (value) {
                      final uri = Uri.tryParse(value?.trim() ?? '');
                      if (uri == null ||
                          uri.scheme != 'https' ||
                          uri.host.isEmpty ||
                          uri.userInfo.isNotEmpty ||
                          uri.hasQuery ||
                          uri.hasFragment) {
                        return 'Enter an HTTPS base URL without credentials or query parameters.';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('personal-ai-key'),
                  controller: _key,
                  enabled: !_testing,
                  obscureText: !_showKey,
                  keyboardType: TextInputType.visiblePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [],
                  spellCheckConfiguration:
                      const SpellCheckConfiguration.disabled(),
                  smartDashesType: SmartDashesType.disabled,
                  smartQuotesType: SmartQuotesType.disabled,
                  onChanged: _changed,
                  decoration: InputDecoration(
                    labelText: 'API key',
                    suffixIcon: IconButton(
                      key: const Key('personal-ai-key-visibility'),
                      tooltip: _showKey ? 'Hide API key' : 'Show API key',
                      onPressed: _testing
                          ? null
                          : () => setState(() => _showKey = !_showKey),
                      icon: Icon(
                        _showKey
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.isEmpty) return 'Paste your API key.';
                    if (text.length > 4096 ||
                        text.codeUnits.any((c) => c < 33 || c > 126)) {
                      return 'The API key contains unsupported characters or is too long.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.pale,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Your key stays in memory for this app session and is excluded from backups. AI requests go directly to $_destination. API usage is billed by your provider.',
                    key: const Key('personal-ai-privacy'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.green,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _provider == AiProvider.openai
                      ? 'Choose a text model that supports structured JSON responses. Web research also requires model support for web search.'
                      : 'Choose a text model that supports structured responses. Web research currently requires an OpenAI model with web search.',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  key: const Key('personal-ai-test'),
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    _testing ? 'Checking connection…' : 'Test connection',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Testing sends one small API request.',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                if (_verified)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Connection verified for this model.',
                      key: Key('personal-ai-verified'),
                      style: TextStyle(
                        color: AppColors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      key: const Key('personal-ai-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  key: const Key('personal-ai-use'),
                  onPressed: _testing ? null : _useKey,
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('Use my API key'),
                ),
                const SizedBox(height: 10),
                TextButton(
                  key: const Key('personal-ai-backend'),
                  onPressed: _testing
                      ? null
                      : () =>
                            Navigator.of(context)
                                .pop(const AiProviderSelection(null)),
                  child: const Text('Use app backend'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
