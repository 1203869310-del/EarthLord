// Supabase Edge Function: generate-items
// 调用阿里云百炼 qwen-flash 模型生成末日生存物品

import { serve } from "https://deno.land/std@0.177.0/http/server.ts"

const DASHSCOPE_API_KEY = Deno.env.get('DASHSCOPE_API_KEY')

const SYSTEM_PROMPT = `你是末日生存游戏《地球新主》的物品生成器。

生成规则：
1. 物品名称要有创意和末日感（15字以内），例如："老张的最后晚餐"、"染血的急救包"、"锈迹斑斑的扳手"
2. 分类必须是以下之一：medical(医疗)、food(食物)、tool(工具)、material(材料)、water(水)
3. 稀有度必须是以下之一：common(普通)、uncommon(优秀)、rare(稀有)、epic(史诗)、legendary(传奇)
4. 背景故事50-100字，营造末日氛围，描述物品的来历或发现场景
5. 物品类型应与场景相关（医院多医疗、超市多食物等）

只返回JSON数组，不要任何其他文字。
格式示例：
[
  {
    "name": "物品名称",
    "category": "medical",
    "rarity": "rare",
    "story": "背景故事..."
  }
]`

interface RequestBody {
  poiType: string
  poiName: string
  dangerLevel: number
  itemCount: number
  rarityDistribution: Record<string, number>
}

serve(async (req: Request) => {
  // CORS 头
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  }

  // 处理 OPTIONS 请求
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // 检查 API Key
    if (!DASHSCOPE_API_KEY) {
      console.error('DASHSCOPE_API_KEY not configured')
      return new Response(
        JSON.stringify({ success: false, error: 'API Key 未配置' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 解析请求
    const body: RequestBody = await req.json()
    const { poiType, poiName, dangerLevel, itemCount, rarityDistribution } = body

    console.log(`生成物品请求: ${poiName} (${poiType}), 危险等级: ${dangerLevel}, 数量: ${itemCount}`)

    // 构建用户提示词
    const userPrompt = `场景：${poiName}（${poiType}类型），危险等级 ${dangerLevel}/5
稀有度分布要求：${formatRarityDistribution(rarityDistribution)}
请根据以上信息生成 ${itemCount} 个物品，返回JSON数组。`

    // 调用阿里云百炼 API
    const response = await fetch('https://dashscope-intl.aliyuncs.com/compatible-mode/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${DASHSCOPE_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        model: 'qwen-turbo',
        messages: [
          { role: 'system', content: SYSTEM_PROMPT },
          { role: 'user', content: userPrompt }
        ],
        temperature: 0.8,
        max_tokens: 2000
      })
    })

    if (!response.ok) {
      const errorText = await response.text()
      console.error('百炼 API 错误:', errorText)
      return new Response(
        JSON.stringify({ success: false, error: `API 调用失败: ${response.status}` }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const data = await response.json()
    console.log('百炼 API 响应:', JSON.stringify(data))

    // 解析 AI 返回的内容
    const content = data.choices?.[0]?.message?.content
    if (!content) {
      return new Response(
        JSON.stringify({ success: false, error: 'AI 未返回内容' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 尝试解析 JSON
    let items
    try {
      // 清理可能的 markdown 代码块标记
      const cleanContent = content
        .replace(/```json\n?/g, '')
        .replace(/```\n?/g, '')
        .trim()
      items = JSON.parse(cleanContent)
    } catch (parseError) {
      console.error('JSON 解析失败:', content)
      return new Response(
        JSON.stringify({ success: false, error: 'AI 返回格式错误' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 验证物品数据
    if (!Array.isArray(items) || items.length === 0) {
      return new Response(
        JSON.stringify({ success: false, error: '物品列表为空' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 验证并规范化每个物品
    const validatedItems = items.map(item => ({
      name: String(item.name || '未知物品').slice(0, 15),
      category: validateCategory(item.category),
      rarity: validateRarity(item.rarity),
      story: String(item.story || '一个神秘的物品。').slice(0, 200)
    }))

    console.log(`成功生成 ${validatedItems.length} 个物品`)

    return new Response(
      JSON.stringify({ success: true, items: validatedItems }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('处理请求时出错:', error)
    return new Response(
      JSON.stringify({ success: false, error: String(error) }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// 格式化稀有度分布
function formatRarityDistribution(distribution: Record<string, number>): string {
  const parts = []
  if (distribution.common > 0) parts.push(`普通${(distribution.common * 100).toFixed(0)}%`)
  if (distribution.uncommon > 0) parts.push(`优秀${(distribution.uncommon * 100).toFixed(0)}%`)
  if (distribution.rare > 0) parts.push(`稀有${(distribution.rare * 100).toFixed(0)}%`)
  if (distribution.epic > 0) parts.push(`史诗${(distribution.epic * 100).toFixed(0)}%`)
  if (distribution.legendary > 0) parts.push(`传奇${(distribution.legendary * 100).toFixed(0)}%`)
  return parts.join('、')
}

// 验证分类
function validateCategory(category: string): string {
  const validCategories = ['medical', 'food', 'tool', 'material', 'water']
  const normalized = String(category).toLowerCase()
  return validCategories.includes(normalized) ? normalized : 'material'
}

// 验证稀有度
function validateRarity(rarity: string): string {
  const validRarities = ['common', 'uncommon', 'rare', 'epic', 'legendary']
  const normalized = String(rarity).toLowerCase()
  return validRarities.includes(normalized) ? normalized : 'common'
}
