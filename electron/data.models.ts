export interface DefaultUserSettings extends UserSettings {
  timeLimitInSeconds: 600; //* 10 minutes
}
export interface UserSettings {
  timeLimitInSeconds: number;
  errorsCoefficient?: number;
  /**
   * * Any of these preferences overrides current lesson's
   */
  isTutorGloballyActive?: boolean;
  isKeyboardGloballyVisible?: boolean;
  minimumWPM?: number;
}

export interface UserData {
  settings: UserSettings;
  // TODO user theme settings
  //   themeSettings?: themeSettings;
  // TODO users' custom lessons
  // customLessons?: lesson[]
}

export interface LessonData {
  text: string;
  isTutorActive: boolean;
  isKeyboardVisible: boolean;
  WPMNeededToPass: number;
}