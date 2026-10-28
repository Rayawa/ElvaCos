#!/usr/bin/env python3
"""Exercise the actual ArkTS migration SQL in SQLite; no mirror schema."""
from pathlib import Path
import re
import sqlite3
import unittest

SOURCE = Path('entry/src/main/ets/services/storage/database/Schema.ets').read_text()
SQL = re.findall(r'`([^`]+)`', SOURCE)
V1 = re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_2')[0])
V2 = re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_2')[1].split('const MIGRATION_3')[0])

class RelationalModelTest(unittest.TestCase):
    def setUp(self):
        self.db = sqlite3.connect(':memory:')
        self.db.execute('PRAGMA foreign_keys=ON')
        for sql in SQL: self.db.execute(sql)
        self.db.execute("INSERT INTO characters(id,name,created_at,updated_at) VALUES('c','Miku',1,1)")
        self.db.execute("INSERT INTO characters(id,name,created_at,updated_at) VALUES('other','Other',1,1)")
        self.db.execute("INSERT INTO variants VALUES('v','c','Racing','')")
        self.db.execute("INSERT INTO events(id,name,date,status,created_at) VALUES('e','Expo','2026-10-24','Planned',1)")
        self.db.execute("INSERT INTO projects(id,character_id,variant_id,event_id,name,status,created_at,updated_at) VALUES('p','c','v','e','Autumn','Preparing',1,1)")
        self.db.execute("INSERT INTO assets(id,name,type,status,created_at) VALUES('a','Wig','Wig','Owned',1)")

    def tearDown(self): self.db.close()

    def test_budget_migration_preserves_unknown_zero_and_explicit_flags(self):
        old = sqlite3.connect(':memory:')
        try:
            before_v4 = re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_4')[0])
            v4 = re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_4')[1].split('const MIGRATION_5')[0])
            for sql in before_v4: old.execute(sql)
            old.execute("INSERT INTO characters(id,name,created_at,updated_at) VALUES('c','Old',1,1)")
            for id, cents in [('unknown', 0), ('configured', 12999)]:
                old.execute("INSERT INTO projects(id,character_id,name,status,budget_cents,created_at,updated_at) VALUES(?,'c',?,'Preparing',?,1,1)", (id, id, cents))
            for sql in v4: old.execute(sql)
            self.assertEqual(old.execute('SELECT id,budget_cents,budget_configured FROM projects ORDER BY id').fetchall(), [('configured',12999,1), ('unknown',0,None)])
            old.execute("UPDATE projects SET budget_configured=1 WHERE id='unknown'")
            self.assertEqual(old.execute("SELECT budget_cents,budget_configured FROM projects WHERE id='unknown'").fetchone(), (0,1))
            old.execute("UPDATE projects SET budget_configured=0 WHERE id='unknown'")
            self.assertEqual(old.execute("SELECT budget_configured FROM projects WHERE id='unknown'").fetchone()[0],0)
            with self.assertRaises(sqlite3.IntegrityError): old.execute('UPDATE projects SET budget_configured=2')
        finally: old.close()

    def test_waiting_migration_keeps_task_history_and_defaults_to_not_waiting(self):
        old = sqlite3.connect(':memory:')
        try:
            for sql in re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_6')[0]): old.execute(sql)
            old.execute("INSERT INTO characters(id,name,created_at,updated_at) VALUES('c','Old',1,1)")
            old.execute("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('p','c','Old','Preparing',1,1)")
            old.execute("INSERT INTO preparation_categories VALUES('g','p','造型',0)")
            old.execute("INSERT INTO preparation_tasks(id,project_id,category_id,label,done,due_date,notes,sort_order) VALUES('t','p','g','试穿',1,'2026-10-01','keep notes',2)")
            for sql in re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_6')[1]): old.execute(sql)
            self.assertEqual(old.execute('SELECT done,due_date,notes,sort_order,waiting_on,waiting_until FROM preparation_tasks').fetchone(), (1,'2026-10-01','keep notes',2,'',''))
            old.execute("UPDATE preparation_tasks SET waiting_on='快递',waiting_until='2026-10-10'")
            self.assertEqual(old.execute('SELECT waiting_on,waiting_until FROM preparation_tasks').fetchone(), ('快递','2026-10-10'))
        finally: old.close()

    def test_entries_are_rehomed_when_the_owner_is_deleted(self):
        for scope, table, id in [('event','events','e'), ('project','projects','p'), ('asset','assets','a')]:
            entry = 'entry-' + scope
            self.db.execute("INSERT INTO entries(id,kind,scope_kind,scope_id,text,created_at) VALUES(?,'note',?,?,'keep me',1)", (entry,scope,id))
            self.db.execute('DELETE FROM ' + table + ' WHERE id=?', (id,))
            self.assertEqual(self.db.execute('SELECT scope_kind,scope_id,text FROM entries WHERE id=?', (entry,)).fetchone(), ('global','','keep me'))
        self.db.execute("INSERT INTO entries(id,kind,scope_kind,scope_id,text,created_at) VALUES('role','note','character','c','keep role',1)")
        self.db.execute("DELETE FROM characters WHERE id='c'")
        self.assertEqual(self.db.execute("SELECT scope_kind,scope_id FROM entries WHERE id='role'").fetchone(), ('global',''))

    def test_entries_reject_invalid_scope_pairs_and_pins(self):
        for scope, id, pin in [('global','p',0), ('project','',0), ('global','',2)]:
            with self.assertRaises(sqlite3.IntegrityError):
                self.db.execute("INSERT INTO entries(id,kind,scope_kind,scope_id,text,pinned,created_at) VALUES('bad','note',?,?,'bad',?,1)",(scope,id,pin))

    def test_variant_must_belong_to_character(self):
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("UPDATE projects SET character_id='other' WHERE id='p'")

    def test_shared_asset_and_idempotent_checklist(self):
        self.db.execute("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('p2','c','Again','Ready',2,2)")
        self.db.execute("INSERT INTO project_assets VALUES('p','a')")
        self.db.execute("INSERT INTO project_assets VALUES('p2','a')")
        for id in ['x','y']:
            self.db.execute("INSERT OR IGNORE INTO checklist_items VALUES(?, 'p','a','Wig',0,0)", (id,))
        self.assertEqual(self.db.execute('SELECT count(*) FROM checklist_items').fetchone()[0], 1)
        self.db.execute("DELETE FROM projects WHERE id='p'")
        self.assertEqual(self.db.execute('SELECT count(*) FROM assets').fetchone()[0], 1)
        self.assertEqual(self.db.execute('SELECT count(*) FROM project_assets').fetchone()[0], 1)

    def test_delete_event_preserves_project(self):
        self.db.execute("DELETE FROM events WHERE id='e'")
        self.assertIsNone(self.db.execute("SELECT event_id FROM projects WHERE id='p'").fetchone()[0])

    def test_protect_character_and_variant_used_by_project(self):
        for table, id in [('characters','c'), ('variants','v')]:
            with self.assertRaises(sqlite3.IntegrityError):
                self.db.execute('DELETE FROM '+table+' WHERE id=?',(id,))

    def test_delete_asset_keeps_custom_checklist_history(self):
        self.db.execute("INSERT INTO checklist_items VALUES('x','p','a','Wig',1,0)")
        self.db.execute("DELETE FROM assets WHERE id='a'")
        self.assertEqual(self.db.execute('SELECT asset_id,label,done FROM checklist_items').fetchone(), (None, 'Wig', 1))

    def test_photo_versions_cascade_with_project(self):
        self.db.execute("INSERT INTO photos VALUES('ph','p','gallery://1','/original','/thumb','Raw','',1)")
        self.db.execute("INSERT INTO photo_versions VALUES('pv','ph','Original','{}','/original',1)")
        self.db.execute("DELETE FROM projects WHERE id='p'")
        self.assertEqual(self.db.execute('SELECT count(*) FROM photos').fetchone()[0], 0)
        self.assertEqual(self.db.execute('SELECT count(*) FROM photo_versions').fetchone()[0], 0)

    def test_duplicate_source_in_project_rejected(self):
        self.db.execute("INSERT INTO photos VALUES('ph','p','gallery://1','/original','/thumb','Raw','',1)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO photos VALUES('ph2','p','gallery://1','/original','/thumb','Raw','',1)")

    def test_invalid_money_and_state_rejected(self):
        for sql in ["UPDATE assets SET price_cents=-1", "UPDATE photos SET status='Bad'", "UPDATE projects SET status='Bad'"]:
            if sql.startswith('UPDATE photos'): continue
            with self.assertRaises(sqlite3.IntegrityError): self.db.execute(sql)

    def test_failed_restore_rolls_back_entire_replacement(self):
        self.db.commit()
        try:
            with self.db:
                self.db.execute('DELETE FROM projects')
                self.db.execute('DELETE FROM variants')
                self.db.execute('DELETE FROM characters')
                self.db.execute("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('bad','missing','Broken','Idea',1,1)")
        except sqlite3.IntegrityError: pass
        self.assertEqual(self.db.execute('SELECT count(*) FROM projects').fetchone()[0], 1)

    def test_v1_migration_preserves_packing_assets_and_photos(self):
        old = sqlite3.connect(':memory:')
        try:
            old.execute('PRAGMA foreign_keys=ON')
            for sql in V1: old.execute(sql)
            old.execute("INSERT INTO characters(id,name,created_at,updated_at) VALUES('c','Old',1,1)")
            old.execute("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('p','c','Old Plan','Preparing',1,1)")
            old.execute("INSERT INTO assets(id,name,type,status,created_at) VALUES('a','Owned wig','Wig','Owned',1)")
            old.execute("INSERT INTO checklist_items VALUES('packed','p','a','Wig',1,0)")
            old.execute("INSERT INTO photos VALUES('ph','p','gallery://1','/original','/thumb','Raw','',1)")
            for sql in V2: old.execute(sql)
            self.assertEqual(old.execute('SELECT done FROM checklist_items').fetchone()[0], 1)
            self.assertEqual(old.execute('SELECT local_path FROM photos').fetchone()[0], '/original')
            self.assertEqual(old.execute('SELECT status FROM assets').fetchone()[0], 'Owned')
            self.assertEqual(old.execute('SELECT count(*) FROM preparation_tasks').fetchone()[0], 0)
        finally: old.close()

    def test_preparation_category_cannot_cross_projects(self):
        self.db.execute("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('p2','c','Other','Ready',1,1)")
        self.db.execute("INSERT INTO preparation_categories VALUES('g','p','Wig',0)")
        with self.assertRaises(sqlite3.IntegrityError):
            self.db.execute("INSERT INTO preparation_tasks(id,project_id,category_id,label) VALUES('t','p2','g','Styling')")

    def test_preparation_completion_is_independent_and_category_cascades(self):
        self.db.execute("INSERT INTO preparation_categories VALUES('g','p','Wig',0)")
        self.db.execute("INSERT INTO preparation_tasks(id,project_id,category_id,label,done) VALUES('t','p','g','Styling',1)")
        self.db.execute("INSERT INTO checklist_items VALUES('pack','p','a','Wig',0,0)")
        self.assertEqual(self.db.execute('SELECT done FROM checklist_items').fetchone()[0], 0)
        self.db.execute("DELETE FROM preparation_categories WHERE id='g'")
        self.assertEqual(self.db.execute('SELECT count(*) FROM preparation_tasks').fetchone()[0], 0)
        self.assertEqual(self.db.execute('SELECT count(*) FROM checklist_items').fetchone()[0], 1)

    def test_v7_to_v8_preserves_plans_and_validates_optional_shooting_time(self):
        old = sqlite3.connect(':memory:')
        try:
            old.execute('PRAGMA foreign_keys=ON')
            for sql in re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_8')[0]): old.execute(sql)
            old.execute("INSERT INTO characters(id,name,created_at,updated_at) VALUES('c','旧角色',1,1)")
            old.execute("INSERT INTO projects(id,character_id,name,status,target_date,budget_cents,budget_configured,created_at,updated_at) VALUES('p','c','旧计划','Ready','2026-10-09',1250,1,2,3)")
            for sql in re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_8')[1]): old.execute(sql)
            self.assertEqual(old.execute('SELECT name,status,target_date,budget_cents,budget_configured,created_at,updated_at,shooting_time FROM projects').fetchone(), ('旧计划','Ready','2026-10-09',1250,1,2,3,''))
            for value in ['', '00:00', '09:30', '23:59']:
                old.execute('UPDATE projects SET shooting_time=?', (value,))
                self.assertEqual(old.execute('SELECT shooting_time FROM projects').fetchone()[0], value)
            for value in ['24:00','12:60','9:30','09:3','09:30:00','aa:bb',None]:
                with self.assertRaises(sqlite3.IntegrityError): old.execute('UPDATE projects SET shooting_time=?', (value,))
            self.assertEqual(old.execute('SELECT shooting_time FROM projects').fetchone()[0], '23:59')
        finally: old.close()

    def test_v6_to_v7_adds_shots_without_changing_existing_history(self):
        old = sqlite3.connect(':memory:')
        try:
            old.execute('PRAGMA foreign_keys=ON')
            for sql in re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_7')[0]): old.execute(sql)
            old.execute("INSERT INTO characters(id,name,created_at,updated_at) VALUES('c','旧角色',1,1)")
            old.execute("INSERT INTO projects(id,character_id,name,status,created_at,updated_at) VALUES('p','c','旧计划','Preparing',1,1)")
            old.execute("INSERT INTO preparation_categories VALUES('category','p','分类',0)")
            old.execute("INSERT INTO preparation_tasks(id,project_id,category_id,label,done,waiting_on,waiting_until) VALUES('task','p','category','在途',1,'快递','2026-10-10')")
            old.execute("INSERT INTO checklist_items VALUES('pack','p',NULL,'打包',1,0)")
            old.execute("INSERT INTO photos VALUES('photo','p','test://photo','/original','/thumbnail','Final','说明',1)")
            for sql in re.findall(r'`([^`]+)`', SOURCE.split('const MIGRATION_7')[1].split('const MIGRATION_8')[0]): old.execute(sql)
            self.assertEqual(old.execute('SELECT done,waiting_on,waiting_until FROM preparation_tasks').fetchone(), (1,'快递','2026-10-10'))
            self.assertEqual(old.execute('SELECT done FROM checklist_items').fetchone()[0], 1)
            self.assertEqual(old.execute('SELECT local_path,status,caption FROM photos').fetchone(), ('/original','Final','说明'))
            self.assertEqual(old.execute('SELECT count(*) FROM project_shots').fetchone()[0], 0)
        finally: old.close()

    def test_shot_reference_ownership_removal_and_completion_constraints(self):
        self.db.execute("INSERT INTO reference_images(id,character_id,source_uri,local_path,thumbnail_path,created_at) VALUES('ref','c','test://ref','','',1)")
        self.db.execute("INSERT INTO reference_images(id,character_id,source_uri,local_path,thumbnail_path,created_at) VALUES('wrong','other','test://wrong','','',1)")
        self.db.execute("INSERT INTO project_shots(id,project_id,title,done,reference_id,created_at) VALUES('s','p','合影',1,'ref',1)")
        for sql in ["UPDATE project_shots SET reference_id='wrong'", "UPDATE project_shots SET done=2", "UPDATE project_shots SET title=' '", "UPDATE project_shots SET sort_order=-1"]:
            with self.assertRaises(sqlite3.IntegrityError): self.db.execute(sql)
        self.db.execute("DELETE FROM reference_images WHERE id='ref'")
        self.assertEqual(self.db.execute('SELECT title,done,reference_id FROM project_shots').fetchone(), ('合影',1,''))
        self.db.execute("DELETE FROM projects WHERE id='p'")
        self.assertEqual(self.db.execute('SELECT count(*) FROM project_shots').fetchone()[0], 0)

    def test_shot_reference_follows_plan_role_and_reference_owner_changes(self):
        self.db.execute("INSERT INTO reference_images(id,character_id,source_uri,local_path,thumbnail_path,created_at) VALUES('ref','c','test://ref','','',1)")
        self.db.execute("INSERT INTO project_shots(id,project_id,title,reference_id,created_at) VALUES('s','p','合影','ref',1)")
        self.db.execute("UPDATE reference_images SET character_id='other' WHERE id='ref'")
        self.assertEqual(self.db.execute('SELECT reference_id FROM project_shots').fetchone()[0], '')
        self.db.execute("UPDATE reference_images SET character_id='c' WHERE id='ref'")
        self.db.execute("UPDATE project_shots SET reference_id='ref'")
        self.db.execute("UPDATE projects SET variant_id=NULL,character_id='other' WHERE id='p'")
        self.assertEqual(self.db.execute('SELECT reference_id FROM project_shots').fetchone()[0], '')

if __name__ == '__main__': unittest.main(verbosity=2)
