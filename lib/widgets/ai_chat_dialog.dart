import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/gemini_service.dart';
import '../theme/app_theme.dart';

class AIChatDialog extends StatefulWidget {
  const AIChatDialog({super.key});

  @override
  State<AIChatDialog> createState() => _AIChatDialogState();
}

class _AIChatDialogState extends State<AIChatDialog> {
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final List<_ChatMessage> _messages = [];
  List<FunctionCall>? _pendingCalls;
  bool _isLoading = false;
  bool _showApiKeyInput = false;
  bool _shouldAutoFocus = false;

  @override
  void initState() {
    super.initState();
    // Check if API key is already set
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!provider.hasGeminiApiKey) {
      _showApiKeyInput = true;
    } else {
      // API 키가 있으면 자동으로 입력창에 포커스
      _shouldAutoFocus = true;
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _apiKeyController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.background,
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1),
            Flexible(
              child: _buildChatArea(),
            ),
            if (_pendingCalls != null) _buildApprovalArea(),
            const Divider(height: 1),
            _buildInputArea(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 18,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 8),
          const Text(
            'AI 어시스턴트',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          // API key status indicator
          if (provider.hasGeminiApiKey)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 12, color: Colors.green),
                  SizedBox(width: 4),
                  Text(
                    'API 연결됨',
                    style: TextStyle(fontSize: 10, color: Colors.green),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _showApiKeyInput = !_showApiKeyInput),
            child: const Icon(
              Icons.settings_outlined,
              size: 18,
              color: AppTheme.textTertiary,
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(
              Icons.close,
              size: 18,
              color: AppTheme.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    if (_showApiKeyInput) {
      return _buildApiKeySetup();
    }

    if (_messages.isEmpty) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_outlined,
                  size: 28,
                  color: AppTheme.textTertiary.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 8),
                Text(
                  '할 일 관리를 도와드릴게요',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Available Functions
            const Text(
              '사용 가능한 기능',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            
            // TODO Functions
            _buildFunctionCategory(
              icon: Icons.check_circle_outline,
              title: '할 일',
              color: AppTheme.accent,
              functions: [
                '추가: "운동하기 30분 할일 추가해줘"',
                '수정: "운동하기를 헬스장 가기로 변경해줘"',
                '삭제: "운동하기 삭제해줘"',
                '완료: "운동하기 완료해줘"',
              ],
            ),
            const SizedBox(height: 12),
            
            // Routine Functions
            _buildFunctionCategory(
              icon: Icons.repeat,
              title: '루틴',
              color: Colors.orange,
              functions: [
                '추가: "매일 아침 운동 루틴 만들어줘"',
                '추가: "월수금 영어 공부 루틴 만들어줘"',
                '수정: "운동 루틴을 저녁 운동으로 바꿔줘"',
                '종료일: "운동 루틴 3월 31일까지로 설정해줘"',
                '삭제: "운동 루틴 삭제해줘"',
              ],
            ),
            const SizedBox(height: 12),
            
            // Calendar Functions
            _buildFunctionCategory(
              icon: Icons.event,
              title: '캘린더',
              color: Colors.blue,
              functions: [
                '추가: "내일 2시에 회의 일정 추가해줘"',
                '수정: "회의 일정을 3시로 변경해줘"',
                '삭제: "회의 일정 삭제해줘"',
              ],
            ),
            const SizedBox(height: 12),
            
            // Conversion Functions
            _buildFunctionCategory(
              icon: Icons.swap_horiz,
              title: '변환',
              color: Colors.purple,
              functions: [
                '"운동하기를 내일 2시에 캘린더에 추가해줘"',
                '"운동하기를 매일 루틴으로 만들어줘"',
              ],
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        return _buildMessageBubble(message);
      },
    );
  }

  Widget _buildApiKeySetup() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gemini API 키 설정',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Google AI Studio에서 API 키를 발급받아 입력해주세요.\n키는 안전하게 저장되며 다시 입력하지 않아도 됩니다.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              hintText: provider.hasGeminiApiKey ? '새 API 키 (기존 키 유지하려면 비워두세요)' : 'API 키 입력',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppTheme.accent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              if (provider.hasGeminiApiKey)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _showApiKeyInput = false);
                    },
                    child: const Text('취소'),
                  ),
                ),
              if (provider.hasGeminiApiKey) const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saveApiKey,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('저장'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              // Open Google AI Studio link
            },
            child: const Text(
              '→ Google AI Studio에서 키 발급받기',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.accent,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(_ChatMessage message) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentLight,
              ),
              child: const Icon(
                Icons.auto_awesome,
                size: 12,
                color: AppTheme.accent,
              ),
            ),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isUser ? AppTheme.textPrimary : AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isUser ? AppTheme.background : AppTheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalArea() {
    if (_pendingCalls == null || _pendingCalls!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(
          top: BorderSide(color: AppTheme.divider, width: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '다음 작업을 수행합니다:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...(_pendingCalls!.map((call) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      size: 14,
                      color: AppTheme.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        call.description,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ))),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _rejectCalls,
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _approveCalls,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('실행'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              autofocus: _shouldAutoFocus && !_showApiKeyInput,
              enabled: provider.hasGeminiApiKey && !_showApiKeyInput,
              decoration: InputDecoration(
                hintText: provider.hasGeminiApiKey 
                    ? '무엇을 도와드릴까요?' 
                    : 'API 키를 먼저 설정해주세요',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppTheme.accent),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.divider.withValues(alpha: 0.5)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isLoading || !provider.hasGeminiApiKey ? null : _sendMessage,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: provider.hasGeminiApiKey ? AppTheme.accent : AppTheme.textTertiary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      size: 18,
                      color: Colors.white,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    if (key.isEmpty) {
      // If key is empty and we already have one, just close the setup
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (provider.hasGeminiApiKey) {
        setState(() => _showApiKeyInput = false);
        return;
      }
    }
    
    if (key.isNotEmpty) {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.setGeminiApiKey(key);
      _apiKeyController.clear();
      setState(() {
        _showApiKeyInput = false;
        _messages.add(_ChatMessage(
          text: 'API 키가 저장되었습니다! 이제 AI 기능을 사용할 수 있습니다.',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _messageController.clear();
      _isLoading = true;
    });

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      final calls = await provider.parseAIRequest(text);

      setState(() {
        _isLoading = false;
        
        if (calls.isEmpty) {
          _messages.add(_ChatMessage(
            text: '요청을 이해하지 못했습니다. "아침 운동 30분 추가해줘" 같이 말씀해주세요.',
            isUser: false,
          ));
        } else if (calls.first.name == 'error') {
          _messages.add(_ChatMessage(
            text: calls.first.description,
            isUser: false,
          ));
        } else {
          _pendingCalls = calls;
          _messages.add(_ChatMessage(
            text: '아래 작업을 확인하고 실행해주세요.',
            isUser: false,
          ));
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          text: '오류가 발생했습니다. 다시 시도해주세요.',
          isUser: false,
        ));
      });
    }
  }

  Future<void> _approveCalls() async {
    if (_pendingCalls == null) return;

    setState(() => _isLoading = true);

    try {
      final provider = Provider.of<AppProvider>(context, listen: false);
      await provider.executeAIFunctionCalls(_pendingCalls!);

      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          text: '완료! 할 일이 추가되었습니다.',
          isUser: false,
        ));
        _pendingCalls = null;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(
          text: '실행 중 오류가 발생했습니다. 다시 시도해주세요.',
          isUser: false,
        ));
        _pendingCalls = null;
      });
    }
  }

  void _rejectCalls() {
    setState(() {
      _pendingCalls = null;
      _messages.add(_ChatMessage(
        text: '취소되었습니다. 다른 요청이 있으시면 말씀해주세요.',
        isUser: false,
      ));
    });
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}

Widget _buildFunctionCategory({
  required IconData icon,
  required String title,
  required Color color,
  required List<String> functions,
}) {
  return Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...functions.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• ', style: TextStyle(fontSize: 11, color: AppTheme.textTertiary)),
              Expanded(
                child: Text(
                  f,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
        )),
      ],
    ),
  );
}
