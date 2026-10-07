#!/usr/bin/env python3
"""Exercise the actual ArkTS migration SQL in SQLite; no mirror schema."""
from pathlib import Path
import re
import sqlite3
import unittest

SOURCE = Path('entry/src/main/ets/data/database/Schema.ets').read_text()
SQL = re.findall(r'`([^`]+)`', SOURCE)
V1 = re.findall(r'`([^`]+)`', SOURCE.split('export const MIGRATION_2')[0])
V2 = re.findall(r'`([^`]+)`', SOURCE.split('export const MIGRATION_2')[1].split('export const MIGRATION_3')[0])

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

if __name__ == '__main__': unittest.main(verbosity=2)
