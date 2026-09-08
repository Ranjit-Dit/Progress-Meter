import 'dotenv/config';
import dataSource from './data-source';
import { AssessmentQuestion } from './entities/assessment-question.entity';
import { CareerRole } from './entities/career-role.entity';
import { CareerRoleSkill } from './entities/career-role-skill.entity';
import { Course } from './entities/course.entity';
import { CourseSkill } from './entities/course-skill.entity';
import { SkillCategory } from './entities/skill-category.entity';
import { Skill } from './entities/skill.entity';

const catalog = [
  {
    category: 'Programming',
    skills: ['JavaScript', 'TypeScript', 'Python', 'SQL'],
  },
  { category: 'Frontend', skills: ['HTML', 'CSS', 'React'] },
  {
    category: 'DevOps',
    skills: [
      'Linux',
      'Git',
      'Docker',
      'Kubernetes',
      'AWS',
      'Terraform',
      'CI/CD',
    ],
  },
  { category: 'Data', skills: ['Excel', 'Power BI', 'Data Analysis'] },
];

async function seed() {
  await dataSource.initialize();
  const categories = dataSource.getRepository(SkillCategory);
  const skills = dataSource.getRepository(Skill);
  const roles = dataSource.getRepository(CareerRole);

  for (const item of catalog) {
    let category = await categories.findOne({ where: { name: item.category } });
    if (!category)
      category = await categories.save(
        categories.create({ name: item.category }),
      );
    for (const name of item.skills) {
      const slug = name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, '-')
        .replace(/(^-|-$)/g, '');
      if (!(await skills.findOne({ where: { slug } })))
        await skills.save(skills.create({ name, slug, category }));
    }
  }

  const bySlug = new Map(
    (await skills.find()).map((skill) => [skill.slug, skill]),
  );
  const roleDefinitions = [
    {
      name: 'DevOps Engineer',
      slug: 'devops-engineer',
      requirements: [
        ['linux', 3, 5],
        ['git', 3, 4],
        ['docker', 4, 5],
        ['kubernetes', 3, 4],
        ['aws', 3, 4],
        ['terraform', 3, 5],
        ['ci-cd', 3, 4],
      ],
    },
    {
      name: 'Frontend Developer',
      slug: 'frontend-developer',
      requirements: [
        ['html', 4, 5],
        ['css', 4, 5],
        ['javascript', 4, 5],
        ['typescript', 3, 4],
        ['react', 4, 5],
        ['git', 3, 3],
      ],
    },
    {
      name: 'Data Analyst',
      slug: 'data-analyst',
      requirements: [
        ['excel', 4, 4],
        ['sql', 4, 5],
        ['power-bi', 3, 4],
        ['data-analysis', 4, 5],
        ['python', 3, 3],
      ],
    },
  ];
  const roleSkills = dataSource.getRepository(CareerRoleSkill);
  for (const definition of roleDefinitions) {
    let role = await roles.findOne({ where: { slug: definition.slug } });
    if (!role)
      role = await roles.save(
        roles.create({ name: definition.name, slug: definition.slug }),
      );
    for (const [slug, requiredLevel, priority] of definition.requirements as [
      string,
      number,
      number,
    ][]) {
      const skill = bySlug.get(slug)!;
      if (
        !(await roleSkills.findOne({
          where: { careerRole: { id: role.id }, skill: { id: skill.id } },
        }))
      )
        await roleSkills.save(
          roleSkills.create({
            careerRole: role,
            skill,
            requiredLevel,
            priority,
            weight: priority,
          }),
        );
    }
  }

  const courses = dataSource.getRepository(Course);
  const courseSkills = dataSource.getRepository(CourseSkill);
  for (const definition of [
    {
      title: 'Docker Foundations',
      provider: 'Progress Learning',
      skills: ['docker', 'linux'],
    },
    {
      title: 'React Frontend Path',
      provider: 'Progress Learning',
      skills: ['react', 'typescript', 'javascript'],
    },
    {
      title: 'SQL for Data Analysis',
      provider: 'Progress Learning',
      skills: ['sql', 'data-analysis', 'excel'],
    },
  ]) {
    let course = await courses.findOne({ where: { title: definition.title } });
    if (!course)
      course = await courses.save(
        courses.create({
          title: definition.title,
          provider: definition.provider,
          estimatedHours: 12,
        }),
      );
    for (const slug of definition.skills) {
      const skill = bySlug.get(slug)!;
      if (
        !(await courseSkills.findOne({
          where: { course: { id: course.id }, skill: { id: skill.id } },
        }))
      )
        await courseSkills.save(
          courseSkills.create({ course, skill, priority: 4 }),
        );
    }
  }

  const questions = dataSource.getRepository(AssessmentQuestion);
  for (const [slug, prompt, options, correctAnswer] of [
    [
      'docker',
      'Which command lists running Docker containers?',
      ['docker ps', 'docker build', 'docker init'],
      'docker ps',
    ],
    [
      'git',
      'Which command creates a new Git commit?',
      ['git commit', 'git push', 'git clone'],
      'git commit',
    ],
    [
      'react',
      'Which hook stores component state?',
      ['useState', 'useEffect', 'useMemo'],
      'useState',
    ],
  ] as [string, string, string[], string][]) {
    const skill = bySlug.get(slug)!;
    if (
      !(await questions.findOne({ where: { skill: { id: skill.id }, prompt } }))
    )
      await questions.save(
        questions.create({
          skill,
          prompt,
          options,
          correctAnswer,
          difficulty: 1,
        }),
      );
  }
  await dataSource.destroy();
  console.log('Progress demo catalog seeded successfully.');
}

void seed();
