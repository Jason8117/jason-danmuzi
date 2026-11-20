import 'package:material_ui/material_ui.dart';

/// Starting points for common errands. Selecting one pre-fills the new call form.
class CallTemplate {
  const CallTemplate({required this.label, required this.icon, required this.goal, this.targetHint = ''});

  final String label;
  final IconData icon;
  final String goal;
  final String targetHint;
}

const callTemplates = [
  CallTemplate(
    label: '식당 예약',
    icon: Icons.restaurant_rounded,
    goal: '이번 주 금요일 저녁 7시에 2명 예약하고 싶어요. 안 되면 가까운 시간으로 알아봐 주세요.',
    targetHint: '예: 라 파스타 강남점',
  ),
  CallTemplate(
    label: '영업시간 문의',
    icon: Icons.schedule_rounded,
    goal: '오늘 영업시간과 주차 가능 여부를 물어봐 주세요.',
    targetHint: '예: 동네 세탁소',
  ),
  CallTemplate(
    label: '요금 할인 요청',
    icon: Icons.savings_outlined,
    goal: '휴대폰 요금이 너무 많이 나와요. 지금 받을 수 있는 할인이나 더 저렴한 요금제가 있는지 알아봐 주세요.',
    targetHint: '예: 통신사 고객센터',
  ),
  CallTemplate(
    label: '취소·환불',
    icon: Icons.undo_rounded,
    goal: '지난주 주문한 상품을 취소하고 환불받고 싶어요. 수수료가 있는지 확인해 주세요.',
    targetHint: '예: 온라인 쇼핑몰 고객센터',
  ),
  CallTemplate(
    label: '병원 진료 예약',
    icon: Icons.local_hospital_outlined,
    goal: '다음 주 화요일 오전에 진료 예약이 가능한지 알아봐 주세요.',
    targetHint: '예: 서울 정형외과',
  ),
];
