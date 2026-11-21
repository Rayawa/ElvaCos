import { FormDraftStore } from './FormDraftStore';
import { getFormDraftData, setFormDraftData } from '../services/storage';

export const formDraftStore: FormDraftStore = new FormDraftStore({ read: getFormDraftData, write: setFormDraftData });
