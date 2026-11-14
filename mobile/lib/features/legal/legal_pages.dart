import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/extensions/context_extensions.dart';
import '../../core/l10n/tr.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/site_scaffold.dart';
import '../../core/widgets/ui.dart';
import 'legal_text.dart' as legal;

/// Company details an admin enters. Empty until then.
class CompanyDetails {
  const CompanyDetails({
    this.name = '',
    this.registrationNo = '',
    this.pan = '',
    this.address = '',
    this.email = '',
  });

  factory CompanyDetails.fromJson(Map<String, dynamic> j) => CompanyDetails(
    name: j['company_name'] as String? ?? '',
    registrationNo: j['registration_no'] as String? ?? '',
    pan: j['pan'] as String? ?? '',
    address: j['address'] as String? ?? '',
    email: j['email'] as String? ?? '',
  );

  final String name;
  final String registrationNo;
  final String pan;
  final String address;
  final String email;

  bool get isSet => name.isNotEmpty;
}

/// Read without the signed-in user's session, because visitors see the
/// footer before they log in.
final companyProvider = FutureProvider<CompanyDetails>((ref) async {
  try {
    final dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl));
    final response = await dio.get<Map<String, dynamic>>('/v1/settings');
    return CompanyDetails.fromJson(response.data!);
  } on DioException {
    // The footer simply leaves the details out if the server is unreachable.
    return const CompanyDetails();
  }
});

enum LegalKind {
  terms('/terms'),
  privacy('/privacy'),
  refunds('/refunds');

  const LegalKind(this.path);

  final String path;

  legal.LegalDocument get document => switch (this) {
    LegalKind.terms => legal.terms,
    LegalKind.privacy => legal.privacy,
    LegalKind.refunds => legal.refunds,
  };
}

class LegalPage extends ConsumerWidget {
  const LegalPage({required this.kind, super.key});

  final LegalKind kind;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final doc = kind.document;
    final company = ref.watch(companyProvider).value ?? const CompanyDetails();
    final name = company.isSet
        ? company.name
        : 'the company operating Subidha360';
    String fill(String text) => text.replaceAll('{company}', name);
    final muted = context.text.bodyMedium!.copyWith(
      color: context.palette.muted,
    );
    return SiteScaffold(
      children: [
        const SizedBox(height: AppTheme.gapXl),
        PageWidth(
          maxWidth: 820,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doc.title, style: context.text.headlineLarge),
              const SizedBox(height: AppTheme.gapSm),
              Text(
                doc.summary,
                style: context.text.bodyLarge!.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(height: AppTheme.gapLg),
              const InfoBanner(
                tone: Tone.warning,
                icon: Icons.edit_note_rounded,
                title: 'Draft for legal review',
                message:
                    'This page explains how Subidha360 works today. A Nepali lawyer '
                    'must review it before launch. Text in [square brackets] is still '
                    'to be decided.',
              ),
              if (appLanguage == AppLanguage.nepali) ...[
                const SizedBox(height: AppTheme.gapSm),
                InfoBanner(
                  title: tr('Nepali version coming'),
                  message: tr(
                    'This page is in English until a reviewed Nepali version is ready.',
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.only(top: AppTheme.gapMd),
                child: Text('Version ${legal.termsVersion}', style: muted),
              ),
              for (final section in doc.sections) ...[
                const SizedBox(height: AppTheme.gapXl),
                Text(section.heading, style: context.text.titleLarge),
                for (final p in section.paragraphs)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.gapSm),
                    child: SelectableText(
                      fill(p),
                      style: context.text.bodyLarge,
                    ),
                  ),
              ],
              const SizedBox(height: AppTheme.gapXl),
              if (company.isSet)
                Text(companyLine(company), style: muted)
              else
                Text(
                  '[Company name, registration number, PAN and address go here once entered in Admin.]',
                  style: muted,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Subidha360 Pvt. Ltd. · Reg. no. 123/080/081 · PAN 609876543 · Baneshwor".
String companyLine(CompanyDetails c) => [
  c.name,
  if (c.registrationNo.isNotEmpty) '${tr('Reg. no.')} ${c.registrationNo}',
  if (c.pan.isNotEmpty) 'PAN ${c.pan}',
  if (c.address.isNotEmpty) c.address,
  if (c.email.isNotEmpty) c.email,
].join(' · ');
