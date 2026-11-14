import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/url_utils.dart';
import '../../data/models/server_config.dart';
import '../../data/sources/music_source.dart';
import '../../data/sources/source_registry.dart';
import '../../data/sources/subsonic_client.dart';
import '../widgets/brand_mark.dart';
import '../widgets/common.dart';

class ServerLoginPage extends StatefulWidget {
  const ServerLoginPage({super.key, this.existing});

  final ServerConfig? existing;

  @override
  State<ServerLoginPage> createState() => _ServerLoginPageState();
}

class _ServerLoginPageState extends State<ServerLoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _baseUrl;
  late final TextEditingController _fallbackUrl;
  late final TextEditingController _username;
  final TextEditingController _password = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.existing != null;
  bool get _isDemo => widget.existing?.isDemo ?? false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _baseUrl = TextEditingController(text: existing?.baseUrl ?? '');
    _fallbackUrl = TextEditingController(text: existing?.fallbackUrl ?? '');
    _username = TextEditingController(text: existing?.username ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _baseUrl.dispose();
    _fallbackUrl.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    final registry = context.read<SourceRegistry>();
    try {
      final existing = widget.existing;
      ServerConfig config;

      if (_isEditing && _password.text.isEmpty) {
        // 未改密码：沿用已有 token，仅更新地址与显示名。
        final updated = existing!.copyWith(
          name: _name.text.trim().isEmpty
              ? UrlUtils.hostOf(_baseUrl.text.trim())
              : _name.text.trim(),
          baseUrl: UrlUtils.normalizeBase(_baseUrl.text),
          fallbackUrl: UrlUtils.normalizeBase(_fallbackUrl.text),
        );
        final version = await SubsonicClient(updated)
            .call('ping', timeout: const Duration(seconds: 15));
        config = updated.copyWith(serverVersion: '${version['version'] ?? ''}');
        await registry.updateServer(config);
      } else {
        config = await SubsonicClient.probe(
          baseUrl: _baseUrl.text,
          fallbackUrl: _fallbackUrl.text,
          username: _username.text,
          password: _password.text,
          displayName: _name.text,
        );
        if (_isEditing) {
          final merged = ServerConfig(
            id: existing!.id,
            type: config.type,
            name: config.name,
            baseUrl: config.baseUrl,
            fallbackUrl: config.fallbackUrl,
            username: config.username,
            salt: config.salt,
            token: config.token,
            createdAt: existing.createdAt,
            serverVersion: config.serverVersion,
          );
          await registry.updateServer(merged);
        } else {
          await registry.addServer(config);
        }
      }

      if (!mounted) return;
      showToast(
        context,
        '连接成功 · ${config.name}',
        icon: Icons.check_circle_outline_rounded,
      );
      Navigator.of(context).pop(true);
    } on MusicSourceException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '连接失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? '编辑服务器' : '连接音乐服务器')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.page,
              8,
              AppSpace.page,
              30,
            ),
            children: [
              if (!_isEditing) ...[
                Center(
                  child: Column(
                    children: [
                      const BrandMark(size: 46),
                      const SizedBox(height: 12),
                      Text(
                        '连接你的音乐库',
                        style: AppText.h1.copyWith(
                          color: palette.textPrimary,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '支持 Navidrome、Airsonic、Gonic 等 Subsonic 服务',
                        textAlign: TextAlign.center,
                        style: AppText.caption.copyWith(
                          color: palette.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
              ],
              if (_isDemo)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.brandSoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    '演示资料库使用内置示例数据，无需地址与密码。',
                    style: AppText.caption.copyWith(color: palette.brand),
                  ),
                ),
              if (!_isDemo) ...[
                _Label('服务器地址', isRequired: true),
                TextFormField(
                  controller: _baseUrl,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText:
                        'http://192.168.1.8:4533 或 http://[2409:8a62::1]:4533',
                    prefixIcon: Icon(Icons.dns_outlined, size: 19),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入服务器地址';
                    }
                    if (!UrlUtils.isValidBase(value)) {
                      return '地址格式不正确，例如 http://192.168.1.8:4533 或 http://[2409:8a62::1]:4533';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Label('用户名', isRequired: true),
                TextFormField(
                  controller: _username,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    hintText: 'Navidrome 登录用户名',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 19),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return '请输入用户名';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Label('密码', isRequired: !_isEditing),
                TextFormField(
                  controller: _password,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    hintText: _isEditing ? '留空则保持原密码' : '仅用于生成 token，不会保存',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      size: 19,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscure = !_obscure),
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 19,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (_isEditing) return null;
                    if (value == null || value.isEmpty) {
                      return '请输入密码';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                _Label('显示名称'),
                TextFormField(
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: '可选，默认使用服务器域名',
                    prefixIcon: Icon(Icons.badge_outlined, size: 19),
                  ),
                ),
                const SizedBox(height: 14),
                _Label('备用线路'),
                TextFormField(
                  controller: _fallbackUrl,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    hintText: '可选，例如外网域名',
                    prefixIcon: Icon(Icons.swap_horiz_rounded, size: 19),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) return null;
                    if (!UrlUtils.isValidBase(value)) {
                      return '备用线路地址格式不正确';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Text(
                  '备用线路在主线路无法连接时自动启用，适合内网 / 外网切换。',
                  style: AppText.caption.copyWith(
                    color: palette.textTertiary,
                    fontSize: 10.5,
                    height: 1.6,
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.isDark
                        ? const Color(0xFF3A1B1D)
                        : const Color(0xFFFFF1F0),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 17,
                        color: palette.brand,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: AppText.caption.copyWith(
                            color: palette.brand,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              BrandButton(
                label: _isEditing ? '保存并测试连接' : '连接',
                icon: Icons.link_rounded,
                loading: _loading,
                expanded: true,
                onPressed: _submit,
              ),
              if (!_isDemo) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 17,
                        color: palette.textTertiary,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '密码只在本次连接时用于计算 Subsonic token，'
                          '保存在本机的是 salt 与 MD5 哈希，可随时删除服务器清除。',
                          style: AppText.caption.copyWith(
                            color: palette.textTertiary,
                            height: 1.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text, {this.isRequired = false});

  final String text;
  final bool isRequired;

  @override
  Widget build(BuildContext context) {
    final palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 7),
      child: Row(
        children: [
          Text(
            text,
            style: AppText.caption.copyWith(
              color: palette.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
          if (isRequired)
            Text(
              ' *',
              style: AppText.caption.copyWith(
                color: palette.brand,
                fontSize: 11.5,
              ),
            ),
        ],
      ),
    );
  }
}
