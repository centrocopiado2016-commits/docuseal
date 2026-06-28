<template>
  <div
    id="form_completed"
    class="mx-auto max-w-md flex flex-col completed-form"
    dir="auto"
    role="status"
    tabindex="-1"
  >
    <div class="font-medium text-2xl flex items-center space-x-1.5 mx-auto">
      <IconCircleCheck
        class="inline text-green-600"
        aria-hidden="true"
        :width="30"
        :height="30"
      />
      <span class="completed-form-message-title">
        {{ completedMessage.title || (hasSignatureFields ? (hasMultipleDocuments ? t('documents_have_been_signed') : t('document_has_been_signed')) : t('form_has_been_completed')) }}
      </span>
    </div>
    <div
      v-if="completedMessage.body"
      class="mt-2 completed-form-message-body"
    >
      <MarkdownContent
        :string="completedMessage.body"
      />
    </div>
  </div>
</template>

<script>
import { IconCircleCheck } from '@tabler/icons-vue'
import MarkdownContent from './markdown_content'

export default {
  name: 'FormCompleted',
  inheritAttrs: false,
  components: {
    MarkdownContent,
    IconCircleCheck
  },
  inject: ['t'],
  props: {
    hasSignatureFields: {
      type: Boolean,
      required: false,
      default: false
    },
    hasMultipleDocuments: {
      type: Boolean,
      required: false,
      default: false
    },
    withConfetti: {
      type: Boolean,
      required: false,
      default: false
    },
    completedMessage: {
      type: Object,
      required: false,
      default: () => ({})
    }
  },
  async mounted () {
    if (this.withConfetti) {
      const { default: confetti } = await import('canvas-confetti')

      confetti({
        particleCount: 50,
        startVelocity: 30,
        spread: 140
      })
    }

    document.querySelectorAll('#decline_button, #decline_button_mobile, #delegate_button, #delegate_button_mobile').forEach((button) => {
      button.setAttribute('disabled', 'true')
    })
  }
}
</script>
