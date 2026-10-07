#!/usr/bin/env python3
"""Build the bundled relational fixture; no network or device database access."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'entry/src/main/resources/rawfile/demo'
SOURCES = json.loads((DEST / 'sources.json').read_text())
TABLE_NAMES = ['characters', 'variants', 'events', 'projects', 'assets', 'project_assets',
               'checklist_items', 'photos', 'photo_versions', 'diary_entries',
               'preparation_categories', 'preparation_tasks', 'team_members', 'expenses', 'reference_images']
tables = {name: [] for name in TABLE_NAMES}
media = []
def uid(kind, key): return f'demo-v1-{kind}-{key}'
def add(table, **row): tables[table].append(row); return row['id'] if 'id' in row else ''
def day(offset): return f'$day:{offset}'
def stamp(offset): return f'$time:{offset}'
def image(kind, key, owner, source, caption):
    mid = uid(kind, key)
    media.append({'id': mid, 'key': source['key']})
    row = dict(id=mid, source_uri=source['imageUrl']+'#'+mid, local_path='$media/'+mid+'.jpg',
               thumbnail_path='$media/'+mid+'-thumb.jpg', caption=caption, created_at=stamp(-2))
    row.update(owner)
    return row

# Public dates remain fixed; personal dates below move with the import day.
events = [
 ('cp32a', 'COMICUP 32 · 一期', '2026-05-01', '2026-05-02', '杭州', '杭州大会展中心', 'https://www.allcpp.cn/w/7576.do', 'Attended', 1),
 ('cp32b', 'COMICUP 32 · 二期', '2026-05-04', '2026-05-05', '杭州', '杭州大会展中心', 'https://www.allcpp.cn/w/7576.do', 'Attended', 0),
 ('bw', 'BilibiliWorld 2026', '2026-07-10', '2026-07-12', '上海', '国家会展中心（上海）', 'https://bw.bilibili.com/', 'Attended', 1),
 ('cj', 'ChinaJoy 2026', '2026-07-31', '2026-08-03', '上海', '上海新国际博览中心', 'https://btb.chinajoy.net/news/63932', 'Attended', 1),
]
for key,name,start,end,city,venue,url,status,ticket in events:
    add('events', id=uid('event',key),name=name,date=start,end_date=end,date_mode='multiple',time_mode='none',
        start_time='',end_time='',event_type='漫展',city=city,venue=venue,url=url,status=status,
        ticket_purchased=ticket,notes='【示例】展会日期与场馆来自公开资料；参加状态和购票状态为虚构调试记录。',
        created_at=stamp(-60),reminder_id=-1,reminder_minutes=-1)
personal_events = [
 ('makeup','【示例】原神妆造试妆',0,None,'妆造','上海','自用化妆间','start','10:00','','Planned'),
 ('shoot','【示例】绝区零街景拍摄',1,None,'拍摄','上海','模拟霓虹街景棚','range','15:00','18:00','Planned'),
 ('meet','【示例】双 IP 同好聚会',3,None,'聚会','杭州','模拟咖啡厅','range','13:00','16:00','Planned'),
 ('studio','【示例】枫丹主题棚拍',7,8,'拍摄','上海','模拟欧式摄影棚','range','09:30','17:00','Planned'),
 ('pack','【示例】出展装备检查',14,None,'其他','上海','个人工作室','none','','','Planned'),
 ('autumn','【示例】秋日同人交流展',21,22,'漫展','南京','模拟会展场馆','range','09:00','17:00','Wishlist'),
 ('winter','【示例】冬日 Cos 交流会',35,None,'漫展','广州','模拟文化中心','none','','','Wishlist'),
 ('pending','【示例】COMICUP 后续场次关注',None,None,'漫展','杭州','场馆待公布','none','','','Wishlist'),
]
for key,name,start,end,kind,city,venue,mode,begin,finish,status in personal_events:
    add('events',id=uid('event',key),name=name,date=day(start) if start is not None else '',
        end_date=day(end) if end is not None else '',date_mode='pending' if start is None else 'multiple' if end is not None else 'single',
        time_mode=mode,start_time=begin,end_time=finish,event_type=kind,city=city,venue=venue,
        url='https://www.allcpp.cn/' if key=='pending' else '',status=status,ticket_purchased=0,
        notes='【示例】虚构个人安排；日期随导入日平移，不代表真实活动公告。系统提醒未开启。',
        created_at=stamp(-4),reminder_id=-1,reminder_minutes=-1)

looks = {
 'hutao':('梅花帽与红黑配色','护摩之杖轻量道具'), 'raiden':('紫色渐变长辫与振袖','薙草之稻光轻量道具'),
 'nahida':('白绿层次与叶片饰件','草元素手持摆件'), 'furina':('蓝白礼服与礼帽','水元素舞台道具'),
 'ayaka':('浅蓝长发与折扇','折扇与刀鞘'), 'keqing':('紫色双髻与渐变裙摆','雷元素剑道具'),
 'zhongli':('棕金长外套与肩饰','岩元素长柄道具'), 'venti':('绿白披风与贝雷帽','竖琴道具'),
 'ellen':('红黑女仆装与鲨鱼尾','可拆卸剪刀道具'), 'jane':('短发与鼠耳尾饰','轻量双匕首'),
 'miyabi':('狐耳与蓝黑制服','刀鞘与佩刀'), 'anby':('白色短发与绿黑外套','折叠剑道具'),
 'nicole':('粉色双马尾与短外套','手提箱道具'), 'billy':('红色夹克与机械面罩','双枪外形道具'),
 'zhuyuan':('蓝色制服与腰带挂件','不可发射的枪型道具'), 'burnice':('金发与红黑皮衣','轻量喷火器外形道具')}
statuses = ['Preparing','Ready','Planning','PostProduction','Idea','Shooting','Completed','Archived',
            'Preparing','Event','Ready','Planning','Idea','PostProduction','Completed','Archived',
            'Preparing','Shooting','Ready','Planning','PostProduction','Completed','Idea','Preparing']
project_events = ['makeup','shoot','meet','bw',None,'shoot','cp32a','cj','shoot','makeup','meet','autumn',None,'bw','cj','cp32b',
                  'studio','shoot','pack','winter','cj','cp32a',None,'autumn']
photo_states = ['Imported','Raw','Selected','WaitingForRetouch','Retouched','Final','Published','Archived']
asset_states = ['Wish','Ordered','Owned','Repair','Lent','Retired']
char_sources = SOURCES['characters']
for i,s in enumerate(char_sources):
    key=s['key']; cid=uid('character',key)
    ref=image('reference','character-'+key,dict(project_id=None,character_id=cid),s,'【示例参考】'+s['name']+'官方立绘；来源：'+s['sourcePage'])
    add('reference_images',**ref)
    add('characters',id=cid,name=s['name'],work_name=s['work'],description='【示例角色】造型关注：'+looks[key][0]+'。参考页面：'+s['sourcePage'],
        cover=ref['thumbnail_path'],favorite=int(i%3==0),status='Wishlist',created_at=stamp(-30+i),updated_at=stamp(-1))
    for v in range(2):
        add('variants',id=uid('variant',key+'-'+str(v)),character_id=cid,name='默认造型' if v==0 else '同人日常 · 示例',
            notes='官方立绘造型参考' if v==0 else '【示例】用于测试同一角色的不同版本；不代表官方皮肤。')
    assets=[('costume','服装', 'Costume',39900),('wig','假发','Wig',12800),('shoes','鞋','Shoes',15900),
            ('prop',looks[key][1],'Prop',23900),('accessory','配饰','Accessory',6900)]
    for a,(akey,label,typ,price) in enumerate(assets):
        add('assets',id=uid('asset',key+'-'+akey),name=s['name']+' · '+label,type=typ,status=asset_states[(i+a)%6],
            location=['衣柜 A / 上层','假发盒 B / 第 2 格','鞋架 / 下层','道具箱 C','饰品抽屉'][a],brand='示例工作室',
            size=['M','均码','38','可拆卸','均码'][a],price_cents=price+i*100,purchase_url='',
            notes='【示例装备】虚构采购金额与状态；造型参考 '+s['sourcePage'],created_at=stamp(-24+a))
for a,(label,typ,price) in enumerate([('通用棕色美瞳','ContactLens',8900),('哑光底妆套装','Makeup',16800),('便携补妆包','Other',5900),('透明防雨袋','Other',1900)]):
    add('assets',id=uid('asset','shared-'+str(a)),name='【示例】'+label,type=typ,status='Owned',location='通用工具箱 / 第 '+str(a+1)+' 格',
        brand='示例用品',size='通用',price_cents=price,purchase_url='',notes='【示例】多个计划共用，测试装备关联与重复使用。',created_at=stamp(-20))

for i,status in enumerate(statuses):
    s=char_sources[i%16]; key=s['key']; pid=uid('project',str(i)); eid=project_events[i]
    completed=status in ['Completed','Archived']; progressed=status in ['Ready','Event','Shooting','PostProduction','Completed','Archived']
    offset= -15-i if completed else [0,1,3,-7,None,1,-20,-45,1,0,3,21,None,-8,-20,-30,7,1,14,35,-9,-20,None,21][i]
    target=day(offset) if offset is not None else ''
    if eid in ['cp32a','cp32b','bw','cj']: target=next(e[2] for e in events if e[0]==eid)
    add('projects',id=pid,character_id=uid('character',key),variant_id=uid('variant',key+'-'+str(int(i>=16))),
        event_id=uid('event',eid) if eid else None,name=s['name']+' · '+('同人日常试拍' if i>=16 else ['造型准备','出片计划','主题约拍'][i%3]),
        status=status,notes='【示例计划】虚构的个人 Cos 安排。造型重点：'+looks[key][0]+'。可编辑状态、准备任务、装备和预算用于调试。',
        target_date=target,budget_cents=0 if i==4 else 60000 if i==3 else 150000+i*5000,created_at=stamp(-28+i),updated_at=stamp(-i%5))
    for a,akey in enumerate(['costume','wig','shoes','prop','accessory']):
        aid=uid('asset',key+'-'+akey)
        add('project_assets',project_id=pid,asset_id=aid)
        add('checklist_items',id=uid('check',str(i)+'-'+str(a)),project_id=pid,asset_id=aid,
            label=next(r['name'] for r in tables['assets'] if r['id']==aid),done=int(progressed and a<i%6),sort_order=a)
    for a in range(4):
        aid=uid('asset','shared-'+str(a));add('project_assets',project_id=pid,asset_id=aid)
        add('checklist_items',id=uid('check',str(i)+'-shared-'+str(a)),project_id=pid,asset_id=aid,
            label=next(r['name'] for r in tables['assets'] if r['id']==aid),done=int(completed or (progressed and a%2==0)),sort_order=5+a)
    for a,label in enumerate(['身份证与电子票','饮水与小零食']):
        add('checklist_items',id=uid('check',str(i)+'-custom-'+str(a)),project_id=pid,asset_id=None,label=label,done=int(completed),sort_order=9+a)
    for c,(category,tasks) in enumerate([('服装与假发',['确认尺码','试穿并标记调整位置','修剪与定型']),
                                       ('妆造与道具',['试妆并拍照记录','检查道具连接处','练习角色姿势']),
                                       ('拍摄与出行',['整理分镜参考','确认集合地点','预约后期与备份照片'])]):
        cat=uid('category',str(i)+'-'+str(c));add('preparation_categories',id=cat,project_id=pid,name=category,sort_order=c)
        for t,label in enumerate(tasks):
            n=c*3+t; done=int(progressed or n<i%7)
            # A task can be unfinished even when related equipment is already owned.
            add('preparation_tasks',id=uid('task',str(i)+'-'+str(n)),project_id=pid,category_id=cat,label=label,done=done,
                due_date=day(-2 if i%5==0 else (offset or 7)-2+c),notes='【示例】'+('已完成确认' if done else '等待确认细节，可测试截止日期与进度'),sort_order=t)
    for a,(role,name) in enumerate([('摄影','小光'),('妆娘','阿柚'),('后期','青禾')]):
        add('team_members',id=uid('team',str(i)+'-'+str(a)),project_id=pid,role=role,name=name+'（示例）',notes='【示例】虚构协作人，无联系方式。')
    for a,(category,amount) in enumerate([('服装',39900),('假发',12800),('妆造',18000),('摄影',30000),('交通',4800),('门票',9800)]):
        add('expenses',id=uid('expense',str(i)+'-'+str(a)),project_id=pid,name=category+'支出（示例）',category=category,
            amount_cents=amount+i*200,date=day(-10+a),notes='【示例】虚构金额，用于预算、超支与分类统计。',created_at=stamp(-10+a))
    add('reference_images',**image('reference','project-'+str(i),dict(project_id=pid,character_id=None),s,
                                  '【示例参考】'+s['name']+'官方造型；摄影动作与材质参考。来源：'+s['sourcePage']))
    # Finished projects have a full gallery; inspiration-only projects keep an empty gallery.
    photo_count=8 if status in ['PostProduction','Completed','Archived'] else 4 if status in ['Shooting','Event'] else 0
    for p in range(photo_count):
        photo=image('photo',str(i)+'-'+str(p),dict(project_id=pid),s,
                    '【调试占位】'+s['name']+'官方立绘 / 图 '+str(p+1)+'；用于测试选片流程，并非真人 Cos 摄影。')
        photo['status']=photo_states[p%8];photo['created_at']=stamp(-p)
        add('photos',**photo)
        add('photo_versions',id=uid('version',str(i)+'-'+str(p)),photo_id=photo['id'],name='Original',recipe='{}',rendered_path=photo['local_path'],created_at=stamp(-p))
    for a,text in enumerate(['创建造型计划，整理官方立绘参考。','已试穿服装，确认假发和道具的待办。','登记示例花费，检查打包清单与选片状态。']):
        add('diary_entries',id=uid('diary',str(i)+'-'+str(a)),project_id=pid,text='【示例记录】'+text,created_at=stamp(-3+a))

output={'version':1,'tables':[{'name':n,'rows':tables[n]} for n in TABLE_NAMES],'media':media}
(DEST/'dataset.json').write_text(json.dumps(output,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({n:len(r) for n,r in tables.items()},ensure_ascii=False))
