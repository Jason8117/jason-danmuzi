import type { Language } from "../domain/types.js";

export type Scenario = "reservation" | "billing" | "cancellation" | "inquiry";

const KEYWORDS: Record<Exclude<Scenario, "inquiry">, RegExp> = {
  reservation: /예약|자리|테이블|진료|booking|book|reserv|appointment|table/i,
  billing: /요금|할인|청구|납부|프로모션|bill|discount|promo|charge|rate/i,
  cancellation: /취소|환불|해지|반품|cancel|refund|return|terminate/i,
};

export function detectScenario(goal: string): Scenario {
  for (const [scenario, pattern] of Object.entries(KEYWORDS)) {
    if (pattern.test(goal)) return scenario as Scenario;
  }
  return "inquiry";
}

interface ScenarioTemplate {
  steps: string[];
  questions: string[];
  approvalPoints: string[];
  calleeAnswers: string[];
  approvalAsk: string;
}

export const SCENARIO_TEMPLATES: Record<Language, Record<Scenario, ScenarioTemplate>> = {
  ko: {
    reservation: {
      steps: ["AI 비서임을 밝히고 용건 전달", "원하는 날짜·시간·인원 가능 여부 확인", "불가능하면 가까운 대안 시간 확인", "예약 확정 정보 재확인 후 종료"],
      questions: ["요청한 날짜와 시간에 예약이 가능한가요?", "예약금이나 노쇼 위약금이 있나요?", "예약자 이름과 연락처로 확정할 수 있나요?"],
      approvalPoints: ["예약금·보증금 결제가 필요한 경우"],
      calleeAnswers: ["네, 그 시간에 자리 있습니다.", "1인당 1만 원 예약금이 있고, 당일 취소 시 환불이 안 됩니다.", "네, 성함하고 연락처 남겨주시면 확정해 드릴게요."],
      approvalAsk: "예약금 결제가 필요합니다. 진행할까요?",
    },
    billing: {
      steps: ["AI 비서임을 밝히고 본인 확인 범위 안내", "현재 요금제와 사용 기간 기준으로 할인 가능 여부 문의", "제안 조건(금액·약정·위약금) 확인", "조건 변경은 사용자 승인 후에만 진행"],
      questions: ["지금 적용 가능한 할인이나 프로모션이 있나요?", "약정이나 위약금 조건이 바뀌나요?", "변경 시 언제부터 적용되나요?"],
      approvalPoints: ["약정 기간이 늘어나거나 위약금 조건이 생기는 경우"],
      calleeAnswers: ["장기 고객 할인으로 월 5,500원 할인이 가능합니다.", "다만 12개월 약정이 새로 걸립니다.", "다음 달 청구분부터 적용됩니다."],
      approvalAsk: "월 5,500원 할인에 12개월 약정이 붙습니다. 진행할까요?",
    },
    cancellation: {
      steps: ["AI 비서임을 밝히고 취소·환불 요청", "취소 가능 여부와 환불 금액 확인", "수수료가 있으면 사용자에게 확인", "처리 번호와 환불 일정 받아두기"],
      questions: ["취소나 환불이 가능한가요?", "수수료나 차감 금액이 있나요?", "환불은 언제, 어떤 수단으로 되나요?"],
      approvalPoints: ["취소 수수료가 발생하는 경우"],
      calleeAnswers: ["네, 취소 가능합니다.", "다만 취소 수수료 10%가 차감됩니다.", "결제하신 카드로 3~5 영업일 안에 환불됩니다."],
      approvalAsk: "취소 수수료 10%가 차감됩니다. 그래도 취소할까요?",
    },
    inquiry: {
      steps: ["AI 비서임을 밝히고 문의 내용 전달", "필요한 정보를 하나씩 확인", "답변 내용을 복창해 정확히 기록", "감사 인사 후 종료"],
      questions: ["오늘 영업시간이 어떻게 되나요?", "방문 전에 미리 준비해야 할 것이 있나요?", "주차가 가능한가요?"],
      approvalPoints: [],
      calleeAnswers: ["오늘은 오전 10시부터 오후 9시까지 합니다.", "따로 준비하실 건 없고 오시면 됩니다.", "건물 지하 주차장 1시간 무료입니다."],
      approvalAsk: "",
    },
  },
  en: {
    reservation: {
      steps: ["Disclose AI assistant and state the purpose", "Check availability for the requested date, time and party size", "Ask for the closest alternative if unavailable", "Confirm the booking details and close"],
      questions: ["Is the requested date and time available?", "Is there a deposit or no-show fee?", "Can you confirm it under the requester's name?"],
      approvalPoints: ["A deposit or prepayment is required"],
      calleeAnswers: ["Yes, we have a table at that time.", "There is a $10 deposit per person, non-refundable on the day.", "Sure, I can confirm it under that name."],
      approvalAsk: "A deposit is required. Should I go ahead?",
    },
    billing: {
      steps: ["Disclose AI assistant", "Ask about available discounts for the current plan", "Confirm amount, contract and fees", "Only accept changes after user approval"],
      questions: ["Are there any discounts or promotions available?", "Does it change the contract or add fees?", "When would it take effect?"],
      approvalPoints: ["The offer adds a contract or early-termination fee"],
      calleeAnswers: ["We can offer a $5 monthly loyalty discount.", "It does come with a new 12-month contract.", "It starts with the next billing cycle."],
      approvalAsk: "$5/month off with a new 12-month contract. Accept?",
    },
    cancellation: {
      steps: ["Disclose AI assistant and request the cancellation", "Check eligibility and refund amount", "Ask the user before accepting any fee", "Get a reference number and refund timeline"],
      questions: ["Can this be canceled or refunded?", "Are there any fees deducted?", "When and how will the refund arrive?"],
      approvalPoints: ["A cancellation fee applies"],
      calleeAnswers: ["Yes, it can be canceled.", "A 10% cancellation fee will be deducted.", "The refund goes back to the original card in 3–5 business days."],
      approvalAsk: "A 10% cancellation fee applies. Cancel anyway?",
    },
    inquiry: {
      steps: ["Disclose AI assistant and state the question", "Collect the needed information one item at a time", "Read the answers back to confirm", "Thank them and close"],
      questions: ["What are your opening hours today?", "Is there anything to prepare before visiting?", "Is parking available?"],
      approvalPoints: [],
      calleeAnswers: ["We're open from 10 a.m. to 9 p.m. today.", "Nothing special, just come by.", "There's free parking for one hour in the basement."],
      approvalAsk: "",
    },
  },
};
