"use client";

import Link from "next/link";
import { useEffect, useState } from "react";
import { hiringApi } from "@/lib/api";
import type { BoardData, BoardStage, CandidateCardResource } from "@/types/hiring";

interface Props {
  board: BoardData;
  wsId: string;
}

/**
 * Client-side kanban board with HTML5 drag-and-drop.
 *
 * - Drag a candidate card and drop on any stage column to move it.
 * - On drop we update local state immediately (optimistic) then call
 *   `hiringApi.moveApplication`. In mock mode the API is a no-op.
 * - On API error we roll back to the previous board state and surface
 *   a small inline error.
 */
export function KanbanBoard({ board: initial, wsId }: Props) {
  const [stages, setStages] = useState<BoardStage[]>(initial.stages);
  const [draggingId, setDraggingId] = useState<string | null>(null);
  const [dragOverStage, setDragOverStage] = useState<string | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  // Re-sync if initial prop ever changes (e.g. router refresh).
  useEffect(() => setStages(initial.stages), [initial.stages]);

  function findCandidate(appId: string): {
    card: CandidateCardResource;
    fromStageId: string;
  } | null {
    for (const s of stages) {
      const c = s.candidates.find((x) => x.application_id === appId);
      if (c) return { card: c, fromStageId: s.stage_id };
    }
    return null;
  }

  async function moveCard(appId: string, toStageId: string) {
    const found = findCandidate(appId);
    if (!found || found.fromStageId === toStageId) return;

    const prev = stages;
    const next = stages.map((s) => {
      if (s.stage_id === found.fromStageId) {
        return {
          ...s,
          candidates: s.candidates.filter(
            (c) => c.application_id !== appId,
          ),
        };
      }
      if (s.stage_id === toStageId) {
        return { ...s, candidates: [...s.candidates, found.card] };
      }
      return s;
    });

    setStages(next);
    setSavingId(appId);
    setError(null);
    try {
      await hiringApi.moveApplication(appId, { new_stage_id: toStageId });
    } catch (e) {
      console.error(e);
      setStages(prev);
      setError(
        e instanceof Error
          ? `Không di chuyển được: ${e.message}`
          : "Không di chuyển được ứng viên",
      );
    } finally {
      setSavingId(null);
    }
  }

  return (
    <div>
      {error ? (
        <div className="mb-3 rounded border border-red-200 bg-red-50 px-3 py-2 text-sm text-red-700">
          {error}
        </div>
      ) : null}
      <div className="grid grid-flow-col auto-cols-[16rem] gap-3 overflow-x-auto pb-3">
        {stages.map((stage) => {
          const isOver = dragOverStage === stage.stage_id;
          return (
            <div
              key={stage.stage_id}
              onDragOver={(e) => {
                e.preventDefault();
                e.dataTransfer.dropEffect = "move";
                if (dragOverStage !== stage.stage_id) {
                  setDragOverStage(stage.stage_id);
                }
              }}
              onDragLeave={() => {
                if (dragOverStage === stage.stage_id) setDragOverStage(null);
              }}
              onDrop={(e) => {
                e.preventDefault();
                setDragOverStage(null);
                const appId = e.dataTransfer.getData("text/application-id");
                if (appId) void moveCard(appId, stage.stage_id);
              }}
              className={`rounded-lg border bg-slate-50 p-2 transition-colors ${
                isOver ? "bg-brand-50 ring-2 ring-brand" : ""
              }`}
              style={{ borderTop: `4px solid ${stage.color ?? "#94a3b8"}` }}
            >
              <div className="flex items-center justify-between px-1 pb-2 text-sm font-semibold">
                <span>{stage.name}</span>
                <span className="rounded bg-white px-1.5 py-0.5 text-xs text-slate-600">
                  {stage.candidates.length}
                </span>
              </div>
              <div className="space-y-2">
                {stage.candidates.map((c) => {
                  const isDragging = draggingId === c.application_id;
                  const isSaving = savingId === c.application_id;
                  return (
                    <div
                      key={c.application_id}
                      draggable
                      onDragStart={(e) => {
                        e.dataTransfer.setData(
                          "text/application-id",
                          c.application_id,
                        );
                        e.dataTransfer.effectAllowed = "move";
                        setDraggingId(c.application_id);
                      }}
                      onDragEnd={() => {
                        setDraggingId(null);
                        setDragOverStage(null);
                      }}
                      className={`rounded border bg-white p-3 transition ${
                        isDragging ? "opacity-50 ring-2 ring-brand" : ""
                      } ${isSaving ? "opacity-60" : ""}`}
                    >
                      <div className="flex items-start justify-between gap-2">
                        <div className="cursor-grab select-none text-slate-300 active:cursor-grabbing">
                          ⠿
                        </div>
                        <Link
                          href={`/recruiter/${wsId}/applications/${c.application_id}`}
                          className="flex-1 hover:text-brand"
                          onDragStart={(e) => e.stopPropagation()}
                          draggable={false}
                        >
                          <div className="text-sm font-medium">
                            {c.candidate_name}
                          </div>
                          <div className="truncate text-xs text-slate-500">
                            {c.candidate_email}
                          </div>
                        </Link>
                      </div>
                      <div className="mt-2 flex items-center justify-between text-xs">
                        <span className="text-slate-500">
                          {new Date(c.applied_at).toLocaleDateString("vi-VN")}
                        </span>
                        <span className="rounded bg-brand-50 px-1.5 py-0.5 text-brand">
                          {c.score}
                        </span>
                      </div>
                    </div>
                  );
                })}
                {stage.candidates.length === 0 ? (
                  <div className="rounded border border-dashed bg-white p-3 text-center text-xs text-slate-400">
                    Chưa có ứng viên
                  </div>
                ) : null}
              </div>
            </div>
          );
        })}
      </div>
      <p className="mt-2 text-xs text-slate-500">
        Kéo thẻ ứng viên qua cột khác để chuyển stage. Mock mode chỉ cập nhật
        local; thật ra sẽ gọi <code>POST /api/applications/&#123;id&#125;/move</code>.
      </p>
    </div>
  );
}
