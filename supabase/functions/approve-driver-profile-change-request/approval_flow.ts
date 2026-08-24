export type PreparedApproval = {
  requestId: string;
  userId: string;
  oldEmail: string | null;
  newEmail: string | null;
  avatarDraftPath: string | null;
};

export type PublishedAvatar = {
  url: string;
  objectPath: string;
};

export type ApprovalPorts = {
  prepare(requestId: string): Promise<PreparedApproval>;
  publishAvatar(path: string): Promise<PublishedAvatar | null>;
  updateAuthEmail(userId: string, email: string): Promise<void>;
  restoreAuthEmail(userId: string, email: string): Promise<void>;
  finalize(requestId: string, avatarUrl: string | null): Promise<void>;
  rollback(
    requestId: string,
    reason: string,
    compensationFailed: boolean,
  ): Promise<void>;
  removePublishedAvatar(path: string): Promise<void>;
  removeAvatarDraft(path: string): Promise<void>;
};

export async function executeDriverProfileApproval(
  requestId: string,
  ports: ApprovalPorts,
): Promise<{ status: "approved" }> {
  let prepared: PreparedApproval | null = null;
  let publishedAvatar: PublishedAvatar | null = null;
  let emailUpdateAttempted = false;

  try {
    prepared = await ports.prepare(requestId);

    if (prepared.avatarDraftPath) {
      publishedAvatar = await ports.publishAvatar(prepared.avatarDraftPath);
      if (!publishedAvatar) {
        throw new Error("AVATAR_PUBLISH_FAILED");
      }
    }

    if (
      prepared.newEmail &&
      normalizeEmail(prepared.newEmail) !== normalizeEmail(prepared.oldEmail)
    ) {
      emailUpdateAttempted = true;
      await ports.updateAuthEmail(prepared.userId, prepared.newEmail);
    }

    await ports.finalize(requestId, publishedAvatar?.url ?? null);

    if (prepared.avatarDraftPath) {
      try {
        await ports.removeAvatarDraft(prepared.avatarDraftPath);
      } catch {
        // Finalization already succeeded. Draft cleanup is intentionally
        // best-effort and can be retried by a maintenance job.
      }
    }

    return { status: "approved" };
  } catch (error) {
    if (!prepared) throw error;

    const compensationNotes: string[] = [];
    let emailCompensationFailed = false;

    if (emailUpdateAttempted) {
      if (!prepared.oldEmail) {
        emailCompensationFailed = true;
        compensationNotes.push("auth_email_restore=missing_original");
      } else {
        try {
          await ports.restoreAuthEmail(prepared.userId, prepared.oldEmail);
          compensationNotes.push("auth_email_restore=ok");
        } catch {
          emailCompensationFailed = true;
          compensationNotes.push("auth_email_restore=failed");
        }
      }
    }

    if (publishedAvatar) {
      try {
        await ports.removePublishedAvatar(publishedAvatar.objectPath);
        compensationNotes.push("published_avatar_cleanup=ok");
      } catch {
        compensationNotes.push("published_avatar_cleanup=failed");
      }
    }

    const failure = errorMessage(error);
    const reason = [
      `Approval failed: ${failure}`,
      ...compensationNotes,
    ].join("; ").slice(0, 1000);

    try {
      await ports.rollback(
        requestId,
        reason,
        emailCompensationFailed,
      );
    } catch {
      // Preserve the original failure. An applying request is visible to Admin
      // and can be retried idempotently by the same approver.
    }

    throw error;
  }
}

function normalizeEmail(value: string | null): string | null {
  return value?.trim().toLowerCase() ?? null;
}

function errorMessage(error: unknown): string {
  if (error instanceof Error && error.message.trim()) {
    return error.message.trim();
  }
  return "UNKNOWN_APPROVAL_FAILURE";
}
