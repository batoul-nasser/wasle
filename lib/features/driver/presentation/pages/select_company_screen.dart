import 'package:flutter/material.dart';

import 'package:wasle/core/ui/ui.dart';
import 'package:wasle/features/auth/data/auth_service.dart';
import 'waiting_approval_screen.dart';

class SelectCompanyScreen extends StatefulWidget {
  const SelectCompanyScreen({super.key});

  @override
  State<SelectCompanyScreen> createState() => _SelectCompanyScreenState();
}

class _SelectCompanyScreenState extends State<SelectCompanyScreen> {
  final AuthService _authService = AuthService();

  List<Map<String, dynamic>> companies = [];
  String? selectedCompanyId;
  bool isLoading = true;
  bool isSubmitting = false;
  String? errorText;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    try {
      final data = await _authService.getDeliveryCompanies();

      if (!mounted) return;
      setState(() {
        companies = data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
        errorText = 'Failed to load companies';
      });
    }
  }

  Future<void> _sendRequest() async {
    if (selectedCompanyId == null) {
      setState(() {
        errorText = 'Please select a delivery company';
      });
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      setState(() {
        errorText = 'User session not found';
      });
      return;
    }

    try {
      setState(() {
        isSubmitting = true;
        errorText = null;
      });

      await _authService.sendDriverRequest(
        driverProfileId: user.id,
        companyId: selectedCompanyId!,
      );

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const WaitingApprovalScreen(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorText = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Delivery Company'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(
                    title: 'Company Selection',
                    subtitle: 'Choose the company you want to work with',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  InfoCard(
                    title: 'Delivery Company',
                    subtitle: 'You can only submit one request at a time',
                    leading: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        size: 18,
                        color: AppColors.primary,
                      ),
                    ),
                    child: DropdownButtonFormField<String>(
                      initialValue: selectedCompanyId,
                      isExpanded: true,
                      hint: const Text('Select a company'),
                      decoration: const InputDecoration(
                        labelText: 'Company',
                        prefixIcon: Icon(Icons.business_outlined),
                      ),
                      items: companies.map((company) {
                        return DropdownMenuItem<String>(
                          value: company['id'].toString(),
                          child: Text(company['name'].toString()),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedCompanyId = value;
                          errorText = null;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (errorText != null)
                    Text(
                      errorText!,
                      style: AppTextStyles.body.copyWith(color: AppColors.danger),
                    ),
                  const Spacer(),
                  PrimaryButton(
                    label: 'Send Request',
                    icon: Icons.send_rounded,
                    isLoading: isSubmitting,
                    onPressed: _sendRequest,
                  ),
                ],
              ),
            ),
    );
  }
}
