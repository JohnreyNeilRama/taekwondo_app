import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../models/student.dart';
import '../services/photo_processor.dart';
import '../theme/app_theme.dart';
import '../widgets/phone_input.dart';

/// Full-screen form styled after the designed "Taekwondo Information
/// Sheet". Pops with the completed [Student] when saved, or null when
/// dismissed.
class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key, this.initial});

  /// When provided, the form runs in edit mode: every controller is
  /// prefilled from this record and the save button reads
  /// "Save Changes" instead of "Save Student".
  final Student? initial;

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  static const List<String> _sexOptions = ['Male', 'Female'];

  /// Keys for every free-text field on the information sheet.
  static const List<String> _textFields = [
    'fullName',
    'nickname',
    'homeAddress',
    'telephoneNos',
    'cellphoneNo',
    'email',
    'birthDate',
    'religion',
    'status',
    'schoolName',
    'gradeYearCourse',
    'companyNameAddress',
    'fatherName',
    'fatherOccupation',
    'fatherOfficeAddress',
    'fatherContactNos',
    'motherName',
    'motherOccupation',
    'motherOfficeAddress',
    'motherContactNos',
    'guardianName',
    'guardianContactNos',
    'previousMartialArts',
    'otherHobbiesSports',
    'healthConditions',
  ];

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _controllers = {};
  String? _sex;
  DateTime? _birthDate;

  /// The compact picture this student is saved with: the copy every list,
  /// header and avatar draws.
  String _photoBase64 = '';

  /// The original picture as the picker produced it, written beside the compact
  /// copy so the upload is never thrown away.
  ///
  /// It stays empty in edit mode until a new picture is picked: the storage
  /// layer keeps the original a student already has, so an edit can never wipe
  /// the saved picture.
  String _photoFullBase64 = '';

  /// The compact picture decoded once for the preview, so the form does not
  /// re-decode it on every keystroke.
  Uint8List? _previewBytes;

  /// Whether a picked picture is still being prepared (decoded and shrunk).
  bool _preparingPhoto = false;

  /// Set by "Remove photo": tells [_submit] to send [Student.clearPhoto] so
  /// the storage layer empties both saved copies instead of keeping the old
  /// picture, which is what it does whenever the photo fields are simply
  /// empty (an untouched form never carries the saved picture at all).
  bool _removePhoto = false;

  /// The Cellphone No. and Telephone No. this record was opened with, exactly
  /// as the two fields show them.
  ///
  /// They are what keeps a number saved before these rules usable: a field the
  /// user did not touch is never rejected, so opening an old record to change
  /// something else cannot be blocked by a number that was saved in another
  /// shape. Both stay empty while a new student is being added.
  String _initialCellphone = '';
  String _initialTelephone = '';

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    for (final key in _textFields) {
      _controllers[key] = TextEditingController();
    }
    if (initial != null) {
      final values = _fieldValuesOf(initial);
      for (final key in _textFields) {
        _controllers[key]!.text = values[key] ?? '';
      }
      _sex = _sexOptions.contains(initial.sex) ? initial.sex : null;
      _birthDate = _parseBirthDate(initial.birthDate);
      _photoBase64 = initial.photoBase64;
    }
    _initialCellphone = _controllers['cellphoneNo']!.text;
    _initialTelephone = _controllers['telephoneNos']!.text;
    _previewBytes = Student.decodePhoto(_photoBase64);
  }

  /// Maps every form key to the matching value on [student] so edit
  /// mode can prefill the controllers.
  static Map<String, String> _fieldValuesOf(Student student) => {
    'fullName': student.name,
    'nickname': student.nickname,
    'homeAddress': student.homeAddress,
    'telephoneNos': student.telephoneNos,
    'cellphoneNo': student.cellphoneNo,
    'email': student.email,
    'birthDate': student.birthDate,
    'religion': student.religion,
    'status': student.status,
    'schoolName': student.schoolName,
    'gradeYearCourse': student.gradeYearCourse,
    'companyNameAddress': student.companyNameAddress,
    'fatherName': student.fatherName,
    'fatherOccupation': student.fatherOccupation,
    'fatherOfficeAddress': student.fatherOfficeAddress,
    'fatherContactNos': student.fatherContactNos,
    'motherName': student.motherName,
    'motherOccupation': student.motherOccupation,
    'motherOfficeAddress': student.motherOfficeAddress,
    'motherContactNos': student.motherContactNos,
    'guardianName': student.guardianName,
    'guardianContactNos': student.guardianContactNos,
    'previousMartialArts': student.previousMartialArts,
    'otherHobbiesSports': student.otherHobbiesSports,
    'healthConditions': student.healthConditions,
  };

  /// Parses the "MM/DD/YYYY" text stored on [Student.birthDate].
  static DateTime? _parseBirthDate(String value) {
    final parts = value.split('/');
    if (parts.length != 3) return null;
    final month = int.tryParse(parts[0]);
    final day = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (month == null || day == null || year == null) return null;
    return DateTime(year, month, day);
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$month/$day/${date.year}';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1930),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _controllers['birthDate']!.text = _formatDate(picked);
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.of(context).pop(
      Student(
        // Editing keeps the id and the registry number of the record being
        // changed, so the database updates that row; a new student gets both
        // from the storage layer once the form closes.
        id: widget.initial?.id,
        name: _controllers['fullName']!.text.trim(),
        studentNo: widget.initial?.studentNo ?? '',
        nickname: _controllers['nickname']!.text.trim(),
        homeAddress: _controllers['homeAddress']!.text.trim(),
        telephoneNos: _controllers['telephoneNos']!.text.trim(),
        cellphoneNo: _controllers['cellphoneNo']!.text.trim(),
        email: _controllers['email']!.text.trim(),
        birthDate: _birthDate == null ? '' : _formatDate(_birthDate!),
        religion: _controllers['religion']!.text.trim(),
        sex: _sex ?? '',
        status: _controllers['status']!.text.trim(),
        schoolName: _controllers['schoolName']!.text.trim(),
        gradeYearCourse: _controllers['gradeYearCourse']!.text.trim(),
        companyNameAddress: _controllers['companyNameAddress']!.text.trim(),
        fatherName: _controllers['fatherName']!.text.trim(),
        fatherOccupation: _controllers['fatherOccupation']!.text.trim(),
        fatherOfficeAddress: _controllers['fatherOfficeAddress']!.text.trim(),
        fatherContactNos: _controllers['fatherContactNos']!.text.trim(),
        motherName: _controllers['motherName']!.text.trim(),
        motherOccupation: _controllers['motherOccupation']!.text.trim(),
        motherOfficeAddress: _controllers['motherOfficeAddress']!.text.trim(),
        motherContactNos: _controllers['motherContactNos']!.text.trim(),
        guardianName: _controllers['guardianName']!.text.trim(),
        guardianContactNos: _controllers['guardianContactNos']!.text.trim(),
        previousMartialArts: _controllers['previousMartialArts']!.text.trim(),
        otherHobbiesSports: _controllers['otherHobbiesSports']!.text.trim(),
        healthConditions: _controllers['healthConditions']!.text.trim(),
        photoBase64: _photoBase64,
        photoFullBase64: _photoFullBase64,
        clearPhoto: _removePhoto,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
                children: [
                  _sectionTitle('STUDENT DETAILS'),
                  const SizedBox(height: 12),
                  _idPictureRow(),
                  const SizedBox(height: 20),
                  _field(
                    'fullName',
                    label: 'Full Name',
                    hint: 'Enter full name',
                  ),
                  _field('nickname', label: 'Nickname', hint: 'Enter Nickname'),
                  _field(
                    'homeAddress',
                    label: 'Home Address',
                    hint: 'Enter Home Address',
                    maxLines: 2,
                  ),
                  // Digits only, laid out as `917-123-4567` while typing, and
                  // only savable as a full 10-digit number.
                  _field(
                    'telephoneNos',
                    label: 'Telephone No.',
                    hint: 'Enter Telephone No.',
                    keyboardType: TextInputType.phone,
                    inputFormatters: PhoneInput.telephoneFormatters(),
                    validator: (value) => PhoneInput.validateTelephone(
                      value,
                      initial: _initialTelephone,
                    ),
                  ),
                  // Digits only, at most 11 of them: nothing else can be typed
                  // or pasted in.
                  _field(
                    'cellphoneNo',
                    label: 'Cellphone No.',
                    hint: 'Enter Cellphone No.',
                    keyboardType: TextInputType.phone,
                    inputFormatters: PhoneInput.cellphoneFormatters(),
                    validator: (value) => PhoneInput.validateCellphone(
                      value,
                      initial: _initialCellphone,
                    ),
                  ),
                  _field(
                    'email',
                    label: 'Email Address',
                    hint: 'Enter Email Address',
                    keyboardType: TextInputType.emailAddress,
                    textCapitalization: TextCapitalization.none,
                  ),
                  _birthDateField(),
                  _field('religion', label: 'Religion', hint: 'Enter Religion'),
                  _labeledField(
                    'Sex',
                    child: _dropdown(
                      hint: 'Select',
                      value: _sex,
                      items: _sexOptions,
                      onChanged: (v) => setState(() => _sex = v),
                    ),
                  ),
                  _field('status', label: 'Status', hint: 'Enter Status'),
                  _field(
                    'schoolName',
                    label: 'School Name',
                    hint: 'Enter School Name',
                  ),
                  _field(
                    'gradeYearCourse',
                    label: 'Grade / Year / Course',
                    hint: 'Enter Grade / Year / Course',
                  ),
                  _field(
                    'companyNameAddress',
                    label: 'Company Name & Office Address (if working)',
                    hint: 'Enter company name and office address',
                    maxLines: 2,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('PARENTS / GUARDIAN'),
                  const SizedBox(height: 16),
                  _field(
                    'fatherName',
                    label: "Father's Name",
                    hint: "Enter Father's Name",
                  ),
                  _field(
                    'fatherOccupation',
                    label: 'Occupation',
                    hint: "Enter Father's Occupation",
                  ),
                  _field(
                    'fatherOfficeAddress',
                    label: 'Office Address',
                    hint: "Enter Father's Office Address",
                    maxLines: 2,
                  ),
                  _field(
                    'fatherContactNos',
                    label: 'Contact Nos.',
                    hint: "Enter Father's Contact Nos.",
                    keyboardType: TextInputType.phone,
                  ),
                  _field(
                    'motherName',
                    label: "Mother's Name",
                    hint: "Enter Mother's Name",
                  ),
                  _field(
                    'motherOccupation',
                    label: 'Occupation',
                    hint: "Enter Mother's Occupation",
                  ),
                  _field(
                    'motherOfficeAddress',
                    label: 'Office Address',
                    hint: "Enter Mother's Office Address",
                    maxLines: 2,
                  ),
                  _field(
                    'motherContactNos',
                    label: 'Contact Nos.',
                    hint: "Enter Mother's Contact Nos.",
                    keyboardType: TextInputType.phone,
                  ),
                  _field(
                    'guardianName',
                    label: "Guardian's Name (if any)",
                    hint: "Enter Guardian's Name",
                  ),
                  _field(
                    'guardianContactNos',
                    label: 'Contact Nos.',
                    hint: "Enter Guardian's Contact Nos.",
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 24),
                  _sectionTitle('ADDITIONAL QUESTIONS'),
                  const SizedBox(height: 16),
                  _field(
                    'previousMartialArts',
                    label: 'Have you had any previous martial arts training? If yes, please state the style and degree achieved.',
                    hint: 'Enter your answer',
                    maxLines: 3,
                  ),
                  _field(
                    'otherHobbiesSports',
                    label: 'What are your other hobbies and sports?',
                    hint: 'Enter your answer',
                    maxLines: 3,
                  ),
                  _field(
                    'healthConditions',
                    label: 'Do you have health problems or physical conditions we should know about that may affect your training?',
                    hint: 'Enter your answer',
                    maxLines: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.black,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 12),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
              const SizedBox(width: 4),
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'TKD',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TKD Records',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _isEditing ? 'Edit Student' : 'Student Registry',
                      style: const TextStyle(
                        color: Color(0xFFD1D5DB),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    foregroundColor: AppColors.black,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: Text(_isEditing ? 'Save Changes' : 'Save Student'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _idPictureRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 88,
          height: 88,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _photoBytes == null
                ? CustomPaint(
                    painter: const _DashedRectPainter(),
                    child: const Center(
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 30,
                        color: AppColors.muted,
                      ),
                    ),
                  )
                : Image.memory(
                    _photoBytes!,
                    fit: BoxFit.cover,
                    // Drawn at the size of the preview box, so a large saved
                    // picture is never decoded at full size here either.
                    cacheWidth: (88 * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1 x 1 ID Picture',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton(
                    onPressed: _uploadPhoto,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child: const Text('Upload Photo'),
                  ),
                  const SizedBox(width: 8),
                  if (_photoBytes != null)
                    TextButton(
                      onPressed: _removePhotoNow,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.red,
                        minimumSize: const Size(0, 36),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        textStyle: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      child: const Text('Remove'),
                    )
                  else
                    const Flexible(
                      child: Text(
                        'JPG or PNG, up to 5 MB',
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Picks a picture and prepares the two copies the student is saved with.
  ///
  /// The picker already hands over a reasonably sized JPEG; the compact copy is
  /// then produced from it here, before anything is saved. Doing that work at
  /// upload time is what keeps every later page cheap: the lists read the
  /// compact copy alone, so opening the registry costs a few kilobytes per
  /// student instead of hundreds.
  Future<void> _uploadPhoto() async {
    if (_preparingPhoto) return;
    setState(() => _preparingPhoto = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 80,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > _maxPhotoBytes) {
        _showPhotoError('Photo must be 5 MB or smaller.');
        return;
      }
      final name = file.name.toLowerCase();
      if (!name.endsWith('.jpg') &&
          !name.endsWith('.jpeg') &&
          !name.endsWith('.png')) {
        _showPhotoError('Please choose a JPG or PNG image.');
        return;
      }

      final compact = await PhotoProcessor.compactBase64(bytes);
      if (!mounted) return;
      setState(() {
        _photoBase64 = compact;
        _photoFullBase64 = base64Encode(bytes);
        _previewBytes = Student.decodePhoto(compact);
        // A freshly picked picture always wins over an earlier removal.
        _removePhoto = false;
      });
    } catch (error) {
      debugPrint('Photo picker failed: $error');
      _showPhotoError(
        kIsWeb
            ? 'The browser blocked the image picker. Open the app in a new browser tab and try again.'
            : 'Could not open the image picker. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _preparingPhoto = false);
    }
  }

  /// Largest picture accepted from the picker, before the compact copy is
  /// produced from it.
  static const int _maxPhotoBytes = 5 * 1024 * 1024;

  /// Confirms, then clears the picture from the form. Nothing is deleted on
  /// the device until [_submit] is pressed and the record is actually saved;
  /// Cancel on this form leaves the saved picture untouched.
  Future<void> _removePhotoNow() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove photo?'),
        content: const Text(
          'The saved photo will be removed once you save this form.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _photoBase64 = '';
      _photoFullBase64 = '';
      _previewBytes = null;
      _removePhoto = true;
    });
  }

  /// The picture the form is holding, as bytes the preview can draw. Decoded
  /// once into [_previewBytes] rather than on every rebuild.
  Uint8List? get _photoBytes => _previewBytes;

  void _showPhotoError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  OutlineInputBorder _border() => OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: AppColors.border),
  );

  InputDecoration _inputDecoration({String? hint, Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: _border(),
      enabledBorder: _border(),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.black, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.red),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: AppColors.black,
      ),
    );
  }

  Widget _labeledField(String label, {required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
              ),
              const Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  /// One field of the sheet.
  ///
  /// [inputFormatters] and [validator] are only passed by the fields that have
  /// rules of their own (the contact numbers); every other field keeps exactly
  /// the plain behaviour it had.
  Widget _field(
    String key, {
    required String label,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
    FormFieldValidator<String>? validator,
  }) {
    return _labeledField(
      label,
      child: TextFormField(
        controller: _controllers[key],
        maxLines: maxLines,
        keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
        textCapitalization: textCapitalization,
        inputFormatters: inputFormatters,
        decoration: _inputDecoration(hint: hint),
        validator:
            validator ??
            (value) =>
                key == 'fullName' && (value == null || value.trim().isEmpty)
                ? 'Full name is required'
                : null,
      ),
    );
  }

  Widget _birthDateField() {
    return _labeledField(
      'Birth Date',
      child: TextFormField(
        controller: _controllers['birthDate'],
        readOnly: true,
        onTap: _pickBirthDate,
        decoration: _inputDecoration(
          hint: 'MM / DD / YYYY',
          suffixIcon: const Icon(
            Icons.calendar_today_outlined,
            size: 20,
            color: AppColors.muted,
          ),
        ),
      ),
    );
  }

  Widget _dropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: [
        for (final item in items)
          DropdownMenuItem<String>(value: item, child: Text(item)),
      ],
      onChanged: onChanged,
      hint: Text(
        hint,
        style: const TextStyle(color: AppColors.muted, fontSize: 13),
      ),
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.muted),
      decoration: _inputDecoration(),
    );
  }
}

/// Dashed rounded-rect border used by the 1 x 1 ID picture placeholder.
class _DashedRectPainter extends CustomPainter {
  const _DashedRectPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC4C4C4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    const dashWidth = 6.0;
    const dashGap = 4.0;
    for (final metric in path.computeMetrics()) {
      var start = 0.0;
      while (start < metric.length) {
        final end = (start + dashWidth) < metric.length
            ? start + dashWidth
            : metric.length;
        canvas.drawPath(metric.extractPath(start, end), paint);
        start = end + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) => false;
}
