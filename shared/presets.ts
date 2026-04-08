import type { PresetProfile } from './contracts';

export const presetProfiles: PresetProfile[] = [
  {
    id: 'jobs',
    displayName: '乔布斯',
    subtitle: '从反叛青年到产品偏执狂',
    category: 'celebrity',
    coverSeed: 'jobs-black-turtleneck',
    biography:
      '史蒂夫·乔布斯年轻时辍学，迷恋设计、书法与东方哲学。1976年与沃兹尼亚克共同创办苹果，推动个人电脑进入大众市场。1985年离开苹果后经历NeXT与皮克斯阶段，重建了对产品与组织的理解。1997年重返苹果，推动iMac、iPod、iPhone等产品，让苹果从濒危公司走向全球最具影响力的科技品牌之一。',
    highlights: ['辍学与反叛', '创办苹果', '被逐出苹果', '回归并重建帝国'],
    suggestedTopics: ['如何建立伟大的产品文化？', '被赶出自己公司后还要不要回来？', '审美和商业哪个更重要？'],
  },
  {
    id: 'qin',
    displayName: '秦始皇',
    subtitle: '从少年君主到一统天下的统治者',
    category: 'history',
    coverSeed: 'qin-empire-bronze',
    biography:
      '嬴政十三岁即位，早年在权力夹缝中成长，逐步清除权臣势力，建立真正的统治基础。成年后以强硬手段推进兼并战争，完成六国统一，并在制度、度量衡、文字等方面推动中央集权整合。其后期则逐渐走向高压治理、求仙与对秩序失控的恐惧。',
    highlights: ['少年即位', '掌握权柄', '六国统一', '制度整合与高压统治'],
    suggestedTopics: ['统一和自由如何取舍？', '建立帝国最重要的是制度还是铁腕？', '权力会如何改变一个人？'],
  },
  {
    id: 'graduate',
    displayName: '刚毕业的普通人',
    subtitle: '在关系、工作和自我认同之间摇摆',
    category: 'self',
    coverSeed: 'graduate-city-night',
    biography:
      '她在普通家庭长大，大学毕业后进入大城市工作。起初相信只要努力就能稳定下来，但很快在高压工作、租房成本和亲密关系拉扯中感到疲惫。经历一次重要的分手和一次岗位调整后，她开始重新理解“安全感”到底来自哪里，也逐渐从迎合转向设边界。',
    highlights: ['大学毕业进城', '高压工作', '关系受挫', '重新建立边界'],
    suggestedTopics: ['现在该不该离职？', '关系里为什么总是先退让？', '要不要留在大城市继续熬？'],
  },
];
