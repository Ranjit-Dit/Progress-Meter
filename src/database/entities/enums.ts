export enum UserRole {
  STUDENT = 'student',
  INDUSTRY = 'industry',
  ACADEMICIAN = 'academician',
  INSTITUTION_ADMIN = 'institution_admin',
  ADMIN = 'admin',
}

export enum SkillEvidenceSource {
  SELF_DECLARED = 'self_declared',
  ASSESSMENT = 'assessment',
  PROJECT = 'project',
  CERTIFICATION = 'certification',
  INDUSTRY = 'industry',
}

export enum OpportunityType {
  INTERNSHIP = 'internship',
  JOB = 'job',
  APPRENTICESHIP = 'apprenticeship',
  PROJECT = 'project',
  TRAINING = 'training',
}

export enum OpportunityStatus {
  DRAFT = 'draft',
  PUBLISHED = 'published',
  CLOSED = 'closed',
}

export enum ApplicationStatus {
  SUBMITTED = 'submitted',
  SHORTLISTED = 'shortlisted',
  INTERVIEW = 'interview',
  OFFERED = 'offered',
  REJECTED = 'rejected',
  WITHDRAWN = 'withdrawn',
}
