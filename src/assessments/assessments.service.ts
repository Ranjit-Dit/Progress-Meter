import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { AuthenticatedUser } from '../auth/auth.types';
import { AssessmentAnswer } from '../database/entities/assessment-answer.entity';
import { AssessmentAttempt } from '../database/entities/assessment-attempt.entity';
import { AssessmentQuestion } from '../database/entities/assessment-question.entity';
import { SkillEvidenceSource } from '../database/entities/enums';
import { Skill } from '../database/entities/skill.entity';
import { StudentSkill } from '../database/entities/student-skill.entity';
import { Student } from '../database/entities/student.entity';
import { CreateQuestionDto } from './dto/create-question.dto';
import { StartAssessmentDto } from './dto/start-assessment.dto';
import { SubmitAssessmentDto } from './dto/submit-assessment.dto';

@Injectable()
export class AssessmentsService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(AssessmentQuestion)
    private readonly questionsRepository: Repository<AssessmentQuestion>,
    @InjectRepository(AssessmentAttempt)
    private readonly attemptsRepository: Repository<AssessmentAttempt>,
    @InjectRepository(Student)
    private readonly studentsRepository: Repository<Student>,
  ) {}

  async createQuestion(dto: CreateQuestionDto) {
    const skill = await this.dataSource
      .getRepository(Skill)
      .findOne({ where: { id: dto.skillId } });
    if (!skill) throw new NotFoundException('Skill was not found.');
    if (!dto.options.includes(dto.correctAnswer))
      throw new BadRequestException(
        'The correct answer must be one of the options.',
      );
    const question = await this.questionsRepository.save(
      this.questionsRepository.create({
        skill,
        prompt: dto.prompt.trim(),
        options: dto.options,
        correctAnswer: dto.correctAnswer,
        difficulty: dto.difficulty,
      }),
    );
    return {
      id: question.id,
      skillId: skill.id,
      prompt: question.prompt,
      options: question.options,
      difficulty: question.difficulty,
      isActive: question.isActive,
    };
  }

  async start(user: AuthenticatedUser, dto: StartAssessmentDto) {
    const student = await this.getStudentOrThrow(user.id);
    const skill = await this.dataSource
      .getRepository(Skill)
      .findOne({ where: { id: dto.skillId } });
    if (!skill) throw new NotFoundException('Skill was not found.');
    const questions = await this.questionsRepository.find({
      where: { skill: { id: skill.id }, isActive: true },
      select: { id: true, prompt: true, options: true, difficulty: true },
      take: 10,
    });
    if (!questions.length)
      throw new BadRequestException(
        'No active assessment questions are available for this skill.',
      );
    const attempt = await this.attemptsRepository.save(
      this.attemptsRepository.create({ student, skill }),
    );
    return {
      attemptId: attempt.id,
      skill: { id: skill.id, name: skill.name },
      questions,
    };
  }

  async submit(
    user: AuthenticatedUser,
    attemptId: string,
    dto: SubmitAssessmentDto,
  ) {
    const student = await this.getStudentOrThrow(user.id);
    const attempt = await this.attemptsRepository.findOne({
      where: { id: attemptId, student: { id: student.id } },
      relations: { skill: true },
    });
    if (!attempt)
      throw new NotFoundException('Assessment attempt was not found.');
    if (attempt.status !== 'in_progress')
      throw new ConflictException(
        'This assessment attempt has already been submitted.',
      );
    const questionIds = dto.answers.map((answer) => answer.questionId);
    if (new Set(questionIds).size !== questionIds.length)
      throw new BadRequestException('A question can be answered only once.');
    const questions = await this.questionsRepository
      .createQueryBuilder('question')
      .addSelect('question.correctAnswer')
      .where('question.id IN (:...questionIds)', { questionIds })
      .andWhere('question."skillId" = :skillId', { skillId: attempt.skill.id })
      .getMany();
    if (questions.length !== questionIds.length)
      throw new BadRequestException(
        'One or more submitted questions are invalid for this assessment.',
      );
    const correctCount = dto.answers.filter(
      (answer) =>
        questions.find((question) => question.id === answer.questionId)
          ?.correctAnswer === answer.selectedAnswer,
    ).length;
    const score = Number(((correctCount / questions.length) * 100).toFixed(2));
    const proficiencyLevel = Math.max(1, Math.min(5, Math.ceil(score / 20)));

    await this.dataSource.transaction(async (manager) => {
      await manager.save(
        AssessmentAnswer,
        dto.answers.map((answer) =>
          manager.create(AssessmentAnswer, {
            attempt,
            question: { id: answer.questionId },
            selectedAnswer: answer.selectedAnswer,
            isCorrect:
              questions.find((question) => question.id === answer.questionId)
                ?.correctAnswer === answer.selectedAnswer,
          }),
        ),
      );
      attempt.status = 'submitted';
      attempt.score = score;
      attempt.submittedAt = new Date();
      await manager.save(attempt);
      const existing = await manager.findOne(StudentSkill, {
        where: { student: { id: student.id }, skill: { id: attempt.skill.id } },
      });
      await manager.save(
        StudentSkill,
        manager.create(StudentSkill, {
          ...existing,
          student,
          skill: attempt.skill,
          proficiencyLevel: Math.max(
            existing?.proficiencyLevel ?? 0,
            proficiencyLevel,
          ),
          source: SkillEvidenceSource.ASSESSMENT,
          isVerified: score >= 60,
        }),
      );
    });
    return {
      attemptId: attempt.id,
      score,
      correctAnswers: correctCount,
      totalQuestions: questions.length,
      proficiencyLevel,
      verified: score >= 60,
    };
  }

  private async getStudentOrThrow(userId: string) {
    const student = await this.studentsRepository.findOne({
      where: { user: { id: userId } },
    });
    if (!student)
      throw new NotFoundException(
        'Student profile has not been completed yet.',
      );
    return student;
  }
}
