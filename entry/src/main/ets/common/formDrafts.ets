import { FormDraftStore } from '../model/FormDraftStore';
import { getFormDraftData, setFormDraftData } from './storage';

export const formDraftStore: FormDraftStore = new FormDraftStore({ read: getFormDraftData, write: setFormDraftData });
