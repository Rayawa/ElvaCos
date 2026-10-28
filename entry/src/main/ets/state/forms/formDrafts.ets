import { FormDraftStore } from './FormDraftStore';
import { getFormDraftData, setFormDraftData } from '../../services/settings/storage';

export const formDraftStore: FormDraftStore = new FormDraftStore({ read: getFormDraftData, write: setFormDraftData });
