import { assertEquals, assertRejects } from "jsr:@std/assert";

import { executeDriverProfileApproval } from "./approval_flow.ts";

Deno.test("publishes avatar, changes email, then finalizes", async () => {
  const calls: string[] = [];
  const result = await executeDriverProfileApproval("request-1", {
    prepare: async () => ({
      requestId: "request-1",
      userId: "user-1",
      oldEmail: "old@example.com",
      newEmail: "new@example.com",
      avatarDraftPath: "user-1/request-1/avatar.jpg",
    }),
    publishAvatar: async () => {
      calls.push("avatar");
      return {
        url: "https://example.test/driver-avatars/user-1/request-1.jpg",
        objectPath: "user-1/request-1.jpg",
      };
    },
    updateAuthEmail: async () => record(calls, "email"),
    restoreAuthEmail: async () => record(calls, "restore"),
    finalize: async () => record(calls, "finalize"),
    rollback: async () => record(calls, "rollback"),
    removePublishedAvatar: async () => record(calls, "remove-published"),
    removeAvatarDraft: async () => record(calls, "remove-draft"),
  });

  assertEquals(calls, ["avatar", "email", "finalize", "remove-draft"]);
  assertEquals(result.status, "approved");
});

Deno.test("restores email and rolls back when finalize fails", async () => {
  const calls: string[] = [];

  await assertRejects(() =>
    executeDriverProfileApproval("request-2", {
      prepare: async () => ({
        requestId: "request-2",
        userId: "user-2",
        oldEmail: "old@example.com",
        newEmail: "new@example.com",
        avatarDraftPath: "user-2/request-2/avatar.jpg",
      }),
      publishAvatar: async () => {
        calls.push("avatar");
        return {
          url: "https://example.test/driver-avatars/user-2/request-2.jpg",
          objectPath: "user-2/request-2.jpg",
        };
      },
      updateAuthEmail: async () => record(calls, "email"),
      restoreAuthEmail: async () => record(calls, "restore"),
      finalize: async () => {
        calls.push("finalize");
        throw new Error("db failed");
      },
      rollback: async () => record(calls, "rollback"),
      removePublishedAvatar: async () => record(calls, "remove-published"),
      removeAvatarDraft: async () => record(calls, "remove-draft"),
    })
  );

  assertEquals(calls, [
    "avatar",
    "email",
    "finalize",
    "restore",
    "remove-published",
    "rollback",
  ]);
});

Deno.test("reports failed email compensation but still rolls back", async () => {
  const calls: string[] = [];
  let rollbackCompensationFailed = false;

  await assertRejects(() =>
    executeDriverProfileApproval("request-3", {
      prepare: async () => ({
        requestId: "request-3",
        userId: "user-3",
        oldEmail: "old@example.com",
        newEmail: "new@example.com",
        avatarDraftPath: null,
      }),
      publishAvatar: async () => null,
      updateAuthEmail: async () => record(calls, "email"),
      restoreAuthEmail: async () => {
        calls.push("restore");
        throw new Error("auth restore failed");
      },
      finalize: async () => {
        calls.push("finalize");
        throw new Error("db failed");
      },
      rollback: async (_requestId, _reason, compensationFailed) => {
        calls.push("rollback");
        rollbackCompensationFailed = compensationFailed;
      },
      removePublishedAvatar: async () => record(calls, "remove-published"),
      removeAvatarDraft: async () => record(calls, "remove-draft"),
    })
  );

  assertEquals(calls, ["email", "finalize", "restore", "rollback"]);
  assertEquals(rollbackCompensationFailed, true);
});

function record(calls: string[], value: string): void {
  calls.push(value);
}
