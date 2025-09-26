// Game constants and configuration
export const BACKEND_HOST =
  process.env.REACT_APP_BACKEND_HOST || "http://localhost:5004";

export const API_BASE = `${BACKEND_HOST}`;

export const GAME_CONFIG = {
  SOCKET_URL: BACKEND_HOST,
  ANSWER_TIME_LIMIT: 30000, // 30 seconds
  MIN_PLAYERS: 2,
  MAX_STRIKES: 3,
  LOADING_DELAY: 1500,
  AUTO_ADVANCE_DELAY: 2500,
  BUZZER_RESET_DELAY: 1500,
} as const;

export const ROUTES = {
  LOGIN: "/",
  REGISTER: "/register",
  HOSTHOME: "/HostHomePage",
  PLAYERHOME: "/PlayerHomePage",
  HOST: "/host",
  HOSTREJOIN: "/host/rejoin",
  JOIN: "/join",
  AUDIENCE: "/audience",
} as const;

export const GAME_STATUS = {
  WAITING: "waiting",
  ACTIVE: "active",
  FINISHED: "finished",
} as const;

export const SOUND_EFFECTS = {
  BUZZER_OPEN: "buzzerOpen",
  BUZZ: "buzz",
  TEAM_BUZZ: "teamBuzz",
  OTHER_BUZZ: "otherBuzz",
  SECOND_CHANCE: "secondChance",
  CORRECT: "correct",
  OTHER_CORRECT: "otherCorrect",
  WRONG: "wrong",
  OTHER_WRONG: "otherWrong",
  TIMEOUT: "timeout",
  TIMER_TICK: "timerTick",
  ERROR: "error",
  NEXT_QUESTION: "nextQuestion",
  APPLAUSE: "applause",
} as const;

export const TEAM_COLORS = {
  TEAM_1: {
    primary: "orange-400",
    ring: "orange-400",
    gradient: "from-orange-600/30 to-red-600/30",
  },
  TEAM_2: {
    primary: "blue-400",
    ring: "blue-400",
    gradient: "from-blue-600/30 to-purple-600/30",
  },
} as const;

export const ANIMATIONS = {
  CARD_DELAY_BASE: 50,
  CARD_DELAY_INCREMENT: 50,
  FADE_IN_DURATION: 600,
  HOVER_TRANSITION: "all 0.3s ease",
} as const;
