import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

// --- App Theme and Configuration ---
class AppTheme {
  static const Color primary = Color(0xFFE53935);
  static const Color background = Color(0xFFF5F5F5);
  static const Color card = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color accent = Color(0xFFE53935);
}

// --- Main Application ---
void main() {
  runApp(const OmicronApp());
}

class OmicronApp extends StatelessWidget {
  const OmicronApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Omicron',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        textTheme: GoogleFonts.robotoTextTheme(),
        scaffoldBackgroundColor: AppTheme.background,
      ),
      home: const HomeScreen(),
    );
  }
}

// --- Home Screen ---
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _topicController = TextEditingController();
  final _requirementsController = TextEditingController();
  String _summary = 'Your generated summary will appear here...';
  String _findings = 'Identified findings and gaps will be shown here...';
  List<String> _relatedPapers = [];
  bool _isLoading = false;
  String _errorMessage = '';

  // --- Ollama Settings ---
  String _ollamaIp = 'http://localhost:11434';
  String? _selectedModel;
  List<String> _availableModels = [];

  // --- LLM Generated Content for PDF ---
  Map<String, dynamic> _llmGeneratedContent = {};

  @override
  void initState() {
    super.initState();
    _loadAvailableModels();
  }

  // --- UI Building ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(child: _buildMainContent()),
          _buildRelatedPapersPanel(),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 80,
      color: AppTheme.primary,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 40),
            child: Icon(Icons.person, color: Colors.white, size: 40),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 40),
            child: IconButton(
              icon: const Icon(Icons.settings, color: Colors.white, size: 30),
              onPressed: _showSettingsDialog,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTextField('Research Topic', _topicController),
          const SizedBox(height: 20),
          _buildTextField('Requirements', _requirementsController, maxLines: 3),
          const SizedBox(height: 20),
          const Center(
              child: Icon(Icons.arrow_downward,
                  color: AppTheme.textSecondary, size: 30)),
          const SizedBox(height: 20),
          _buildOutputField('Literature Review Analysis', _summary),
          const SizedBox(height: 20),
          _buildOutputField('Key Findings, Gaps & Future Research', _findings),
          const Spacer(),
          Row(
            children: [
              _buildGenerateButton(),
              const SizedBox(width: 20),
              _buildRetryButton(),
              const Spacer(),
              if (_selectedModel != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.psychology,
                          color: AppTheme.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        _selectedModel!,
                        style: GoogleFonts.roboto(
                          fontSize: 12,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text(_errorMessage,
                  style: const TextStyle(color: AppTheme.accent)),
            ),
        ],
      ),
    );
  }

  Widget _buildRelatedPapersPanel() {
    return Container(
      width: 350,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.card,
        border: Border(left: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Related Topics - Papers',
              style: GoogleFonts.roboto(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 20),
          Expanded(
            child: _isLoading && _relatedPapers.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.primary))
                : _relatedPapers.isEmpty
                    ? const Center(
                        child: Text("Related papers will be listed here.",
                            style: TextStyle(color: AppTheme.textSecondary)))
                    : ListView.builder(
                        itemCount: _relatedPapers.length,
                        itemBuilder: (context, index) =>
                            _buildPaperItem(_relatedPapers[index]),
                      ),
          ),
        ],
      ),
    );
  }

  // --- UI Components ---
  Widget _buildTextField(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      enableInteractiveSelection: true,
      contextMenuBuilder: (context, editableTextState) {
        return AdaptiveTextSelectionToolbar.editableText(
          editableTextState: editableTextState,
        );
      },
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textSecondary),
        filled: true,
        fillColor: AppTheme.card,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppTheme.primary, width: 2)),
      ),
    );
  }

  Widget _buildOutputField(String label, String content) {
    return Expanded(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: SingleChildScrollView(
            child: Text(content,
                style: const TextStyle(
                    fontSize: 16, color: AppTheme.textPrimary, height: 1.5))),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _processRequest,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 5,
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text('Generate Literature Review',
              style: TextStyle(fontSize: 18, color: Colors.white)),
    );
  }

  Widget _buildRetryButton() {
    return TextButton(
      onPressed: _retry,
      child: const Row(
        children: [
          Text('Retry',
              style: TextStyle(fontSize: 18, color: AppTheme.textSecondary)),
          SizedBox(width: 8),
          Icon(Icons.refresh, color: AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _buildPaperItem(String title) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      color: AppTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: AppTheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.picture_as_pdf,
              color: AppTheme.primary, size: 24),
        ),
        title: Text(
          title,
          style: GoogleFonts.roboto(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
            fontSize: 14,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _openPaper(title),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  child: const Icon(
                    Icons.open_in_browser_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => _savePaper(title),
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  child: const Icon(
                    Icons.download_outlined,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
        dense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      ),
    );
  }

  // --- Logic ---
  Future<void> _processRequest() async {
    if (_topicController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please provide a topic.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _summary =
          'Generating comprehensive research document... This may take few minutes depending on your LLM model.';
      _findings = 'Analyzing topic and gathering detailed information...';
      _relatedPapers = [];
    });

    try {
      final prompt = '''
You are an expert technical writer. Write a comprehensive research document about: "${_topicController.text}"
${_requirementsController.text.isNotEmpty ? 'Additional requirements: ${_requirementsController.text}' : ''}

Generate detailed, substantive content with real technical information, data, and examples.

Return ONLY valid JSON in this exact structure (replace ALL field values with actual content):

{
  "abstract_objective": "Write 2-3 complete sentences explaining what this research covers",
  "abstract_methods": "Write 3-4 complete sentences about methodology used", 
  "abstract_results": "Write 3-4 complete sentences with key findings and specific data/numbers",
  "abstract_conclusions": "Write 2 complete sentences with main conclusions",
  "introduction_background": "Write 3 full paragraphs (each 5-7 sentences) explaining the topic background, importance, history, challenges, and real-world applications",
  "introduction_objectives": "Write 2 full paragraphs (each 5-7 sentences) stating what this document covers and key questions answered",
  "methods_protocol": "Write 2 full paragraphs about theoretical framework and technical approach",
  "methods_pico": "Write 2 full paragraphs describing scope, systems covered, and constraints",
  "methods_search_strategy": "Write 2 full paragraphs about research methodology and data sources",
  "methods_study_selection": "Write 2 full paragraphs on evaluation criteria used",
  "methods_data_extraction": "Write 2 full paragraphs on data collection techniques",
  "methods_risk_of_bias": "Write 2 full paragraphs on quality assurance methods",
  "methods_synthesis": "Write 2 full paragraphs on analytical framework",
  "results_study_selection": "Write 2 full paragraphs with detailed findings including specific numbers",
  "results_characteristics": "Write 3 full paragraphs describing technical characteristics and specifications with data",
  "results_risk_of_bias": "Write 2 full paragraphs on quality metrics and validation",
  "results_synthesis": "Write 5 full paragraphs with CORE technical content - explain HOW things work, include formulas if relevant, performance data, examples, detailed processes",
  "results_key_findings": "Write 3 full paragraphs highlighting most important discoveries and insights",
  "discussion_summary": "Write 2 full paragraphs summarizing main contributions",
  "discussion_comparison": "Write 2 full paragraphs comparing with existing approaches",
  "discussion_implications": "Write 2 full paragraphs on practical applications",
  "discussion_strengths_limitations": "Write 3 full paragraphs on strengths, limitations, and areas needing improvement",
  "discussion_future_research": "Write 2 full paragraphs with recommendations for future work",
  "conclusions": "Write 2 full paragraphs with overall conclusions and recommendations",
  "related_papers": "Write like given example" [
    "Author, A. et al. (2024). Relevant Paper Title. Journal Name, 45(2), 123-145.",
    "Smith, J. (2023). Another Paper Title. Conference Name, 456-467.",
    "Johnson, M. (2023). Third Paper. Journal Name, 34(5), 789-801.",
    "Williams, P. (2022). Fourth Paper. Nature, 567, 234-240.",
    "Brown, L. (2024). Fifth Paper. Science, 789(12), 567-589.",
    "Davis, C. (2023). Sixth Paper. Publisher, pp. 123-145.",
    "Miller, T. (2023). Seventh Paper. Journal, 23(4), 345-367.",
    "Wilson, K. (2022). Eighth Paper. Review, 15, 89-112."
  ]
}

CRITICAL: Write REAL content, not instructions. Include specific details, numbers, examples. Return ONLY the JSON object.
      ''';

      final response = await _sendToOllama(prompt);

      // Parse the JSON response from Ollama
      Map<String, dynamic> decodedResponse;
      try {
        // Clean up response - remove markdown code blocks if present
        String cleanedResponse = response.trim();
        if (cleanedResponse.startsWith('```json')) {
          cleanedResponse = cleanedResponse.replaceFirst('```json', '').trim();
        }
        if (cleanedResponse.startsWith('```')) {
          cleanedResponse = cleanedResponse.replaceFirst('```', '').trim();
        }
        if (cleanedResponse.endsWith('```')) {
          cleanedResponse = cleanedResponse
              .substring(0, cleanedResponse.lastIndexOf('```'))
              .trim();
        }

        decodedResponse = jsonDecode(cleanedResponse);
        print('DEBUG: Successfully decoded JSON response');
        print('DEBUG: Keys found: ${decodedResponse.keys.toList()}');
        print(
            'DEBUG: Related papers count: ${decodedResponse['related_papers']?.length ?? 0}');
      } catch (e) {
        print('DEBUG: JSON parse error: $e');
        print(
            'DEBUG: Raw response: ${response.substring(0, response.length > 500 ? 500 : response.length)}...');
        throw Exception(
            'Invalid JSON response from Ollama. Please try again or use a different model.');
      }

      setState(() {
        // Store complete LLM generated content for PDF
        _llmGeneratedContent = decodedResponse;

        // Extract for UI display
        _summary = decodedResponse['results_synthesis']?.toString() ??
            decodedResponse['abstract_results']?.toString() ??
            'No summary provided.';
        _findings = decodedResponse['results_key_findings']?.toString() ??
            decodedResponse['discussion_summary']?.toString() ??
            'No findings provided.';

        // Safely handle the related_papers field
        final papersData = decodedResponse['related_papers'];
        print('DEBUG: Papers data type: \\${papersData.runtimeType}');

        if (papersData is List && papersData.isNotEmpty) {
          _relatedPapers = papersData.map((paper) => paper.toString()).toList();
          print('DEBUG: Extracted \\${_relatedPapers.length} papers');
        } else if (papersData is String && papersData.trim().isNotEmpty) {
          _relatedPapers = [papersData];
          print('DEBUG: Single paper as string');
        } else {
          // Fallback: show example papers if LLM fails
          _relatedPapers = [
            "Smith, J. & Doe, K. (2023). Example Paper Title. IEEE Conference, 456-467.",
            "Johnson, M. et al. (2023). Third Paper on Related Topic. ACM Transactions, 34(5), 789-801.",
            "Williams, P. (2022). Fourth Relevant Paper Title. Nature, 567, 234-240.",
            "Brown, L. & Green, R. (2024). Fifth Paper Title. Science, 789(12), 567-589."
          ];
          print('DEBUG: No papers found or invalid format, using fallback.');
        }
      });

      await _generatePdf();
    } catch (e) {
      setState(() => _errorMessage = 'Error: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _retry() {
    setState(() {
      _topicController.clear();
      _requirementsController.clear();
      _summary = 'Your generated summary will appear here...';
      _findings = 'Identified findings and gaps will be shown here...';
      _relatedPapers = [];
      _errorMessage = '';
    });
  }

  Future<void> _generatePdf() async {
    final pdf = pw.Document();
    final String searchDate = DateTime.now().toString().split(' ')[0];
    final String llmModel = _selectedModel ?? 'AI Model Not Specified';

    // PRISMA 2009 Systematic Review Document
    pdf.addPage(
      pw.MultiPage(
        build: (pw.Context context) => [
          // Title Page
          pw.Text(
            _topicController.text.isNotEmpty
                ? _topicController.text.toUpperCase()
                : 'SYSTEMATIC REVIEW',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'A Comprehensive Research Document',
            style: const pw.TextStyle(fontSize: 12),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Generated using Omicron Research Assistant',
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Search Date: $searchDate',
            style: const pw.TextStyle(fontSize: 10),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 20),
          pw.Divider(),
          pw.SizedBox(height: 12),

          // ABSTRACT - LLM Generated
          pw.Text('ABSTRACT',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          pw.RichText(
              text: pw.TextSpan(children: [
            pw.TextSpan(
                text: 'Objective: ',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.TextSpan(
                text:
                    '${_llmGeneratedContent['abstract_objective'] ?? "To systematically review and synthesize evidence on ${_topicController.text.toLowerCase()}."}\n\n',
                style: const pw.TextStyle(fontSize: 11)),
            pw.TextSpan(
                text: 'Methods: ',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.TextSpan(
                text:
                    '${_llmGeneratedContent['abstract_methods'] ?? "A comprehensive literature search was conducted across multiple databases following PRISMA guidelines."}\n\n',
                style: const pw.TextStyle(fontSize: 11)),
            pw.TextSpan(
                text: 'Results: ',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.TextSpan(
                text:
                    '${_llmGeneratedContent['abstract_results'] ?? "${_relatedPapers.length} studies were identified for inclusion."}\n\n',
                style: const pw.TextStyle(fontSize: 11)),
            pw.TextSpan(
                text: 'Conclusions: ',
                style:
                    pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            pw.TextSpan(
                text:
                    '${_llmGeneratedContent['abstract_conclusions'] ?? "Further high-quality research is needed."}\n',
                style: const pw.TextStyle(fontSize: 11)),
          ])),

          pw.SizedBox(height: 16),

          // INTRODUCTION
          pw.Text('1. INTRODUCTION',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          pw.Text('1.1 Background and Rationale',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['introduction_background'] ??
                'This systematic review was conducted to synthesize the current evidence base.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 12),

          pw.Text('1.2 Objectives',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['introduction_objectives'] ??
                'The primary objective was to systematically review the available evidence.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 16),

          // METHODS
          pw.Text('2. METHODOLOGY & TECHNICAL FRAMEWORK',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          pw.Text('2.1 Theoretical Framework',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['methods_protocol'] ??
                'This systematic review was conducted following PRISMA 2009 guidelines.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('2.2 Scope and Parameters',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['methods_pico'] ??
                'Population: ${_topicController.text.isNotEmpty ? _topicController.text : "As specified"}\nIntervention: ${_requirementsController.text.isNotEmpty ? _requirementsController.text : "As defined"}\nComparison: Standard care\nOutcomes: Primary and secondary outcomes',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('2.3 Research Methodology & Data Sources',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['methods_search_strategy'] ??
                'A comprehensive search was conducted across multiple databases.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('2.4 Selection Criteria & Evaluation',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['methods_study_selection'] ??
                'Two independent reviewers screened studies.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('2.5 Data Collection & Analysis',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['methods_data_extraction'] ??
                'Data were extracted using a standardized form.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('2.6 Quality Assurance & Validation',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['methods_risk_of_bias'] ??
                'Risk of bias was assessed using validated tools.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('2.7 Analytical Framework',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['methods_synthesis'] ??
                'Qualitative narrative synthesis was performed.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),

          pw.SizedBox(height: 16),

          // RESULTS
          pw.Text('3. FINDINGS & TECHNICAL DETAILS',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          pw.Text('3.1 Overview of Findings',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['results_study_selection'] ??
                'The systematic search identified ${_relatedPapers.length} studies.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('3.2 Technical Characteristics & Specifications',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['results_characteristics'] ??
                'Table 1 presents the characteristics of included studies.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 8),

          if (_relatedPapers.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Table 1. Characteristics of Included Studies',
                    style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        fontStyle: pw.FontStyle.italic)),
                pw.SizedBox(height: 6),
                ...(_relatedPapers
                    .asMap()
                    .entries
                    .map(
                      (entry) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 4),
                        child: pw.Text(
                          '[${entry.key + 1}] ${entry.value}',
                          style: const pw.TextStyle(
                              fontSize: 10, lineSpacing: 1.2),
                          textAlign: pw.TextAlign.justify,
                        ),
                      ),
                    )
                    .toList()),
              ],
            )
          else
            pw.Text(
                'No studies were identified that met the inclusion criteria.',
                style: const pw.TextStyle(fontSize: 11)),

          pw.SizedBox(height: 10),

          pw.Text('3.3 Quality Metrics & Reliability Analysis',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['results_risk_of_bias'] ??
                'Risk of bias assessment revealed variability in methodological quality.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('3.4 Detailed Analysis & Core Content',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          if (_summary.isNotEmpty &&
              _summary != 'Your generated summary will appear here...' &&
              _summary != 'Generating literature review...')
            pw.Text(_summary,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify)
          else
            pw.Text(
              _llmGeneratedContent['results_synthesis'] ??
                  'Qualitative synthesis was performed.',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
              textAlign: pw.TextAlign.justify,
            ),
          pw.SizedBox(height: 10),

          pw.Text('3.5 Critical Insights & Discoveries',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          if (_findings.isNotEmpty &&
              _findings !=
                  'Identified findings and gaps will be shown here...' &&
              _findings != 'Analyzing findings and gaps...')
            pw.Text(_findings,
                style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
                textAlign: pw.TextAlign.justify)
          else
            pw.Text(
              _llmGeneratedContent['results_key_findings'] ??
                  'Key findings have important implications.',
              style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
              textAlign: pw.TextAlign.justify,
            ),

          pw.SizedBox(height: 16),

          // DISCUSSION
          pw.Text('4. DISCUSSION',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),

          pw.Text('4.1 Summary of Key Contributions',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['discussion_summary'] ??
                'This systematic review comprehensively examined the research question.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('4.2 Comparison with Existing Approaches',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['discussion_comparison'] ??
                'The findings contribute to the growing body of evidence.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('4.3 Practical Applications & Implications',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['discussion_implications'] ??
                'The evidence has implications for clinical practice.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('4.4 Strengths and Limitations',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['discussion_strengths_limitations'] ??
                'Strengths include comprehensive search. Limitations include study heterogeneity.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 10),

          pw.Text('4.5 Future Work & Open Problems',
              style:
                  pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
            _llmGeneratedContent['discussion_future_research'] ??
                'Future research should address identified gaps.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 16),

          // CONCLUSIONS
          pw.Text('5. CONCLUSIONS',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text(
            _llmGeneratedContent['conclusions'] ??
                'This systematic review provides a comprehensive synthesis of the evidence regarding ${_topicController.text.isNotEmpty ? _topicController.text.toLowerCase() : "the research question"}.',
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 1.3),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 16),

          // REFERENCES SECTION
          pw.SizedBox(height: 16),
          pw.Text('6. REFERENCES',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (_relatedPapers.isNotEmpty)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: _relatedPapers
                  .asMap()
                  .entries
                  .map((entry) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 6),
                        child: pw.Text(
                          '[${entry.key + 1}] ${entry.value}',
                          style: const pw.TextStyle(
                              fontSize: 10, lineSpacing: 1.3),
                          textAlign: pw.TextAlign.justify,
                        ),
                      ))
                  .toList(),
            )
          else
            pw.Text(
              'References will be generated based on the research topic.',
              style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
            ),
          pw.SizedBox(height: 16),

          // DOCUMENT METADATA
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text('DOCUMENT INFORMATION',
              style:
                  pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Generated: ${DateTime.now().toString().split('.')[0]}',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Research Tool: Omicron AI Research Assistant',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('AI Model: $llmModel',
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Document Type: Comprehensive Research Document',
              style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );

    try {
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Research Document',
        fileName: 'Research_${_topicController.text.replaceAll(' ', '_')}.pdf',
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(await pdf.save());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('PDF saved successfully to $outputFile'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to save PDF: ${e.toString()}'),
            backgroundColor: AppTheme.accent));
      }
    }
  }

  // --- Ollama Communication ---
  Future<String> _sendToOllama(String prompt) async {
    if (_selectedModel == null) {
      throw Exception('Please select an Ollama model from the settings.');
    }

    print('DEBUG: Sending request to Ollama with model: $_selectedModel');

    final response = await http
        .post(
      Uri.parse('$_ollamaIp/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': _selectedModel,
        'prompt': prompt,
        'stream': false,
        'format': 'json',
        'options': {
          'temperature': 0.7,
          'top_p': 0.9,
          'num_predict': 4096, // Allow longer responses
        }
      }),
    )
        .timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        throw Exception(
            'Request timed out. Try using a smaller model or simpler prompt.');
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = jsonDecode(response.body);
      final llmResponse = jsonResponse['response'];
      print(
          'DEBUG: LLM Response length: ${llmResponse?.length ?? 0} characters');
      return llmResponse;
    } else {
      throw Exception(
          'Failed to connect to Ollama (Status code: ${response.statusCode}).');
    }
  }

  Future<void> _loadAvailableModels() async {
    try {
      final response = await http.get(Uri.parse('$_ollamaIp/api/tags'));
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final modelsData = responseBody['models'];

        List<String> models = [];
        if (modelsData is List) {
          models = modelsData
              .where((model) => model != null && model['name'] != null)
              .map((model) => model['name'].toString())
              .toList();
        }

        setState(() {
          _availableModels = models;
          // Only set default model if none is currently selected
          if (_selectedModel == null && models.isNotEmpty) {
            _selectedModel = models.first;
          }
        });
      }
    } catch (e) {
      setState(() =>
          _errorMessage = 'Failed to connect to Ollama. Check IP in settings.');
    }
  }

  // --- Settings Dialog ---
  void _showSettingsDialog() {
    final ipController = TextEditingController(text: _ollamaIp);
    String? tempModel = _selectedModel;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppTheme.card,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.settings,
                      color: AppTheme.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  'Settings',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ollama Configuration',
                    style: GoogleFonts.roboto(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: ipController,
                    enableInteractiveSelection: true,
                    contextMenuBuilder: (context, editableTextState) {
                      return AdaptiveTextSelectionToolbar.editableText(
                        editableTextState: editableTextState,
                      );
                    },
                    style: GoogleFonts.roboto(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      labelText: 'Ollama IP Address',
                      labelStyle:
                          GoogleFonts.roboto(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: AppTheme.textSecondary.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.computer,
                          color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                    ),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: tempModel,
                    style: GoogleFonts.roboto(color: AppTheme.textPrimary),
                    items: _availableModels
                        .map((model) => DropdownMenuItem(
                              value: model,
                              child: Text(model, style: GoogleFonts.roboto()),
                            ))
                        .toList(),
                    onChanged: (value) =>
                        setDialogState(() => tempModel = value),
                    decoration: InputDecoration(
                      labelText: 'Select LLM Model',
                      labelStyle:
                          GoogleFonts.roboto(color: AppTheme.textSecondary),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(
                            color: AppTheme.textSecondary.withOpacity(0.3)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: AppTheme.primary, width: 2),
                      ),
                      prefixIcon: const Icon(Icons.psychology,
                          color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.background,
                    ),
                    hint: Text(
                      "Select a model",
                      style: GoogleFonts.roboto(color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.textSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text('Cancel', style: GoogleFonts.roboto()),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  setState(() {
                    _ollamaIp = ipController.text;
                    _selectedModel = tempModel;
                  });
                  _loadAvailableModels();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: Text('Save',
                    style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- Paper Management Methods ---
  Future<void> _openPaper(String paperTitle) async {
    try {
      // Extract paper title for search
      String searchQuery = _extractPaperTitle(paperTitle);

      // Create search URLs for multiple academic databases
      List<String> searchUrls = [
        'https://scholar.google.com/scholar?q=${Uri.encodeComponent(searchQuery)}',
        'https://www.semanticscholar.org/search?q=${Uri.encodeComponent(searchQuery)}',
        'https://pubmed.ncbi.nlm.nih.gov/?term=${Uri.encodeComponent(searchQuery)}',
        'https://arxiv.org/search/?query=${Uri.encodeComponent(searchQuery)}',
      ];

      // Show dialog to choose which database to search
      if (context.mounted) {
        _showSearchOptionsDialog(paperTitle, searchUrls);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening paper: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _savePaper(String paperTitle) async {
    try {
      // Show a dialog to get PDF URL or provide instructions
      if (context.mounted) {
        _showSavePaperDialog(paperTitle);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving paper: ${e.toString()}')),
        );
      }
    }
  }

  String _extractPaperTitle(String fullTitle) {
    // Remove author and year information, keep just the title
    // Example: "Title of Paper - Author (Year)" -> "Title of Paper"
    String title = fullTitle;

    // Remove author and year pattern
    title = title.replaceAll(RegExp(r'\s*-\s*[^(]+\(\d{4}\)'), '');

    // Remove any remaining parentheses with years
    title = title.replaceAll(RegExp(r'\s*\(\d{4}\)'), '');

    // Clean up extra spaces
    title = title.trim();

    return title;
  }

  void _showSearchOptionsDialog(String paperTitle, List<String> searchUrls) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.open_in_browser,
                    color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Open Paper',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _extractPaperTitle(paperTitle),
                style: GoogleFonts.roboto(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Choose where to search for this paper:',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text('Cancel', style: GoogleFonts.roboto()),
            ),
            const SizedBox(width: 8),
            _buildSearchButton('Google Scholar', searchUrls[0]),
            const SizedBox(width: 8),
            _buildSearchButton('Semantic Scholar', searchUrls[1]),
            const SizedBox(width: 8),
            _buildSearchButton('PubMed', searchUrls[2]),
            const SizedBox(width: 8),
            _buildSearchButton('ArXiv', searchUrls[3]),
          ],
        );
      },
    );
  }

  Widget _buildSearchButton(String label, String url) {
    return ElevatedButton(
      onPressed: () async {
        Navigator.of(context).pop();
        await _launchUrl(url);
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: GoogleFonts.roboto(
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }

  void _showSavePaperDialog(String paperTitle) {
    TextEditingController urlController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.card,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.download,
                    color: AppTheme.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Save Paper',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _extractPaperTitle(paperTitle),
                  style: GoogleFonts.roboto(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Enter the direct PDF URL to download:',
                  style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlController,
                  enableInteractiveSelection: true,
                  contextMenuBuilder: (context, editableTextState) {
                    return AdaptiveTextSelectionToolbar.editableText(
                      editableTextState: editableTextState,
                    );
                  },
                  style: GoogleFonts.roboto(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'PDF URL',
                    hintText: 'https://example.com/paper.pdf',
                    labelStyle:
                        GoogleFonts.roboto(color: AppTheme.textSecondary),
                    hintStyle: GoogleFonts.roboto(
                        color: AppTheme.textSecondary.withOpacity(0.7)),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                          color: AppTheme.textSecondary.withOpacity(0.3)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide:
                          const BorderSide(color: AppTheme.primary, width: 2),
                    ),
                    prefixIcon:
                        const Icon(Icons.link, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: AppTheme.background,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: AppTheme.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppTheme.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Tip: Find direct PDF links from journal websites, ArXiv, or institutional repositories.',
                          style: GoogleFonts.roboto(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text('Cancel', style: GoogleFonts.roboto()),
            ),
            ElevatedButton(
              onPressed: () async {
                if (urlController.text.trim().isNotEmpty) {
                  Navigator.of(context).pop();
                  await _downloadPdf(urlController.text.trim(), paperTitle);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.download, size: 18),
                  const SizedBox(width: 8),
                  Text('Download',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not launch $url')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching URL: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _downloadPdf(String url, String paperTitle) async {
    try {
      // Show loading indicator
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting download...')),
        );
      }

      // Download the PDF
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        // Get the downloads directory
        final Directory? downloadsDir = await getDownloadsDirectory();
        String savePath;

        if (downloadsDir != null) {
          savePath = downloadsDir.path;
        } else {
          // Fallback to app documents directory
          final Directory appDir = await getApplicationDocumentsDirectory();
          savePath = appDir.path;
        }

        // Create a safe filename
        String safeFileName = _extractPaperTitle(paperTitle)
            .replaceAll(RegExp(r'[^\w\s-]'), '')
            .replaceAll(RegExp(r'\s+'), '_');

        if (safeFileName.length > 50) {
          safeFileName = safeFileName.substring(0, 50);
        }

        final String fileName = '${safeFileName}.pdf';
        final String fullPath = '$savePath/$fileName';

        // Save the file
        final File file = File(fullPath);
        await file.writeAsBytes(response.bodyBytes);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Paper saved to: $fullPath'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Failed to download PDF: HTTP ${response.statusCode}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading PDF: ${e.toString()}')),
        );
      }
    }
  }
}
